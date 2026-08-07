import { spawn, spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { connect } from "node:net";
import path from "node:path";
import process from "node:process";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { parseEnv } from "node:util";

const root = fileURLToPath(new URL("..", import.meta.url));
const npm = process.platform === "win32" ? "npm.cmd" : "npm";
const uv = process.platform === "win32" ? "uv.exe" : "uv";
const signalExitCodes = { SIGHUP: 129, SIGINT: 130, SIGTERM: 143 };
const requiredEnv = [
  "PROJECT_NAME",
  "SECRET_KEY",
  "FIRST_SUPERUSER",
  "FIRST_SUPERUSER_PASSWORD",
  "SIGNUP_ACCESS_PASSWORD",
  "POSTGRES_SERVER",
  "POSTGRES_PORT",
  "POSTGRES_DB",
  "POSTGRES_USER",
  "POSTGRES_PASSWORD",
  "API_PORT",
  "WEB_PORT",
  "DB_PORT",
  "ADMINER_PORT",
];
const children = new Set();

let cleaningUp = false;
let composeStarted = false;
let requestedSignal;
let watcher;

for (const signal of Object.keys(signalExitCodes)) {
  process.on(signal, () => {
    requestedSignal ??= signal;
    if (!cleaningUp) void stopChildren(signal);
  });
}

let exitCode = 0;

try {
  checkEnvironment();
  await required(process.execPath, ["scripts/check-ports.mjs"], "ports");

  composeStarted = true;
  await required("docker", ["compose", "up", "-d", "--wait", "db", "adminer"], "compose");
  await waitForTcp(Number(process.env.DB_PORT), "PostgreSQL");
  await waitForHttp(Number(process.env.ADMINER_PORT), "Adminer");
  await required(npm, ["run", "db:migrate"], "migrations");
  await required(uv, ["run", "--project", "backend", "python", "-m", "app.initial_data"], "seed");

  watcher = startClientWatcher();
  const apiPort = process.env.API_PORT;
  const webPort = process.env.WEB_PORT;
  process.env.FRONTEND_HOST ||= `http://localhost:${webPort}`;
  process.env.VITE_API_URL = `http://localhost:${apiPort}`;

  console.log(
    `\nDevelopment ready: web http://localhost:${webPort}, API http://localhost:${apiPort}, ` +
      `Adminer http://localhost:${process.env.ADMINER_PORT}`,
  );

  const servers = [
    run(
      "backend",
      uv,
      [
        "run",
        "--project",
        "backend",
        "uvicorn",
        "app.main:create_app",
        "--factory",
        "--reload",
        "--reload-dir",
        "backend/app",
        "--host",
        "0.0.0.0",
        "--port",
        apiPort,
      ],
      { processGroup: true },
    ),
    run(
      "frontend",
      npm,
      [
        "--prefix",
        "frontend",
        "run",
        "dev",
        "--",
        "--host",
        "0.0.0.0",
        "--port",
        webPort,
        "--strictPort",
      ],
      { processGroup: true },
    ),
  ];

  const first = await Promise.race(servers);
  exitCode = first.code ?? signalExitCodes[first.signal] ?? 1;
  if (!requestedSignal) {
    const detail = first.error ? `: ${first.error.message}` : "";
    console.error(`\n✗ ${first.name} exited unexpectedly${detail}.`);
    await stopChildren("SIGTERM");
  }
  await Promise.all(servers);
} catch (error) {
  exitCode = error.exitCode ?? 1;
  if (!requestedSignal) console.error(`\n✗ ${error.message}`);
} finally {
  cleaningUp = true;
  watcher?.close();
  await stopChildren(requestedSignal ?? "SIGTERM");
  if (composeStarted) {
    console.log("\nStopping development services…");
    const result = await run("compose", "docker", ["compose", "down"], {
      processGroup: true,
      timeoutMs: 15_000,
    });
    if (result.code !== 0 && exitCode === 0) exitCode = result.code ?? 1;
  }
}

process.exitCode = requestedSignal ? signalExitCodes[requestedSignal] : exitCode;

function checkEnvironment() {
  const envFile = path.join(root, ".env");
  if (!existsSync(envFile)) fail("Missing .env. Copy .env.example to .env first.");
  let values;
  try {
    values = parseEnv(readFileSync(envFile, "utf8"));
  } catch (error) {
    fail(`Could not parse .env. Copy .env.example to .env and fix its syntax. (${error.message})`);
  }

  const missing = requiredEnv.filter((key) => !values[key]?.trim());
  if (missing.length) {
    fail(`Missing required .env keys: ${missing.join(", ")}. Copy them from .env.example.`);
  }
  process.loadEnvFile(envFile);

  const [nodeMajor, nodeMinor] = process.versions.node.split(".").map(Number);
  if (nodeMajor < 20 || (nodeMajor === 20 && nodeMinor < 19)) {
    fail(`Node 20.19 or newer is required (found ${process.versions.node}).`);
  }

  checkCommand(npm, ["--version"], "npm", "Install npm with Node.js 20.19 or newer.");
  checkCommand(uv, ["--version"], "uv", "Install uv, then run `uv sync --project backend`.");
  checkCommand(
    "docker",
    ["compose", "version"],
    "Docker Compose",
    "Install Docker with the Compose plugin.",
  );

  const docker = spawnSync("docker", ["info"], { stdio: "ignore" });
  if (docker.status !== 0) {
    fail("Docker is not running. Start Docker Desktop or your Docker-compatible runtime.");
  }

  const venvPython =
    process.platform === "win32"
      ? path.join(root, "backend", ".venv", "Scripts", "python.exe")
      : path.join(root, "backend", ".venv", "bin", "python");
  if (!existsSync(venvPython)) {
    fail("Backend dependencies are missing. Run `uv sync --project backend`.");
  }

  const vite = path.join(root, "frontend", "node_modules", ".bin", "vite");
  if (!existsSync(vite)) {
    fail("Frontend dependencies are missing. Run `npm --prefix frontend ci`.");
  }
}

function checkCommand(command, args, label, advice) {
  const result = spawnSync(command, args, { stdio: "ignore" });
  if (result.error?.code === "ENOENT") fail(`${label} was not found. ${advice}`);
  if (result.status !== 0) fail(`${label} is unavailable. ${advice}`);
}

function startClientWatcher() {
  let timer;
  let activeRegeneration;
  let pending = false;
  let closed = false;
  const watchedRoot = path.join(root, "backend", "app");
  let snapshot = scanSourceTree(watchedRoot);
  const poller = setInterval(checkForChanges, 300);

  function checkForChanges() {
    if (closed) return;
    let nextSnapshot;
    try {
      nextSnapshot = scanSourceTree(watchedRoot);
    } catch (error) {
      console.warn(`[client] watcher scan failed; retrying: ${error.message}`);
      return;
    }
    const changed = firstChangedPath(snapshot, nextSnapshot);
    snapshot = nextSnapshot;
    if (!changed) return;
    console.log(`[client] backend change detected: backend/app/${changed}`);
    clearTimeout(timer);
    timer = setTimeout(regenerate, 500);
  }

  async function regenerate() {
    if (closed) return;
    if (activeRegeneration) {
      pending = true;
      return;
    }
    console.log("[client] regenerating OpenAPI client and route tree…");
    activeRegeneration = run("client", npm, ["run", "generate-client"], {
      processGroup: true,
    });
    const result = await activeRegeneration;
    activeRegeneration = undefined;

    if (closed || requestedSignal) return;
    if (result.code !== 0) {
      console.warn("[client] regeneration failed; retrying in 2 seconds.");
      timer = setTimeout(regenerate, 2_000);
      return;
    }

    console.log("[client] generated artifacts are up to date.");
    if (pending) {
      pending = false;
      timer = setTimeout(regenerate, 0);
    }
  }

  return {
    close() {
      closed = true;
      clearInterval(poller);
      clearTimeout(timer);
    },
  };
}

function scanSourceTree(directory, relativeDirectory = "") {
  const snapshot = new Map();
  for (const entry of readdirSync(path.join(directory, relativeDirectory), {
    withFileTypes: true,
  })) {
    const relativePath = path.join(relativeDirectory, entry.name);
    if (isIgnoredWatcherPath(relativePath)) continue;
    if (entry.isDirectory()) {
      for (const item of scanSourceTree(directory, relativePath)) snapshot.set(...item);
    } else if (entry.isFile()) {
      const stats = statSync(path.join(directory, relativePath));
      snapshot.set(relativePath, `${stats.mtimeMs}:${stats.size}`);
    }
  }
  return snapshot;
}

function firstChangedPath(previous, next) {
  for (const [filename, fingerprint] of next) {
    if (previous.get(filename) !== fingerprint) return filename;
  }
  for (const filename of previous.keys()) {
    if (!next.has(filename)) return filename;
  }
}

function isIgnoredWatcherPath(candidate) {
  const parts = candidate.split(path.sep);
  const name = parts.at(-1) || "";
  return (
    parts.includes("__pycache__") ||
    name.endsWith(".pyc") ||
    name.endsWith(".swp") ||
    name.endsWith(".swo") ||
    name.endsWith(".tmp") ||
    name.endsWith("~") ||
    name.startsWith(".#") ||
    /^4913(?:\.\d+)?$/.test(name) ||
    name === ".DS_Store"
  );
}

async function waitForTcp(port, label) {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    if (requestedSignal) fail("Development startup was interrupted.");
    if (await canConnect(port)) {
      console.log(`[health] ${label} is reachable on port ${port}`);
      return;
    }
    await delay(250);
  }
  fail(`${label} did not become reachable on port ${port}. Run \`docker compose logs\`.`);
}

async function waitForHttp(port, label) {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    if (requestedSignal) fail("Development startup was interrupted.");
    try {
      const response = await fetch(`http://127.0.0.1:${port}`, {
        redirect: "manual",
        signal: AbortSignal.timeout(1_000),
      });
      if (response.status < 500) {
        console.log(`[health] ${label} answered HTTP ${response.status} on port ${port}`);
        return;
      }
    } catch {}
    await delay(250);
  }
  fail(`${label} did not answer on port ${port}. Run \`docker compose logs adminer\`.`);
}

function canConnect(port) {
  return new Promise((resolve) => {
    const socket = connect({ host: "127.0.0.1", port });
    socket.setTimeout(500);
    socket.once("connect", () => {
      socket.destroy();
      resolve(true);
    });
    socket.once("timeout", () => {
      socket.destroy();
      resolve(false);
    });
    socket.once("error", () => resolve(false));
  });
}

async function required(command, args, label) {
  const result = await run(label, command, args, { processGroup: true });
  if (result.error) throw result.error;
  if (result.code !== 0) {
    const error = new Error(`${label} failed.`);
    error.exitCode = result.code ?? signalExitCodes[result.signal] ?? 1;
    throw error;
  }
}

function run(name, command, args, { processGroup = false, timeoutMs } = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: root,
      stdio: ["ignore", "pipe", "pipe"],
      detached: processGroup && process.platform !== "win32",
      env: process.env,
    });
    const running = { child, name, processGroup };
    children.add(running);
    prefixLines(child.stdout, name, process.stdout);
    prefixLines(child.stderr, name, process.stderr);

    let error;
    let timedOut = false;
    let timeout;
    child.once("error", (value) => {
      error = value;
    });
    if (timeoutMs) {
      timeout = setTimeout(() => {
        timedOut = true;
        signalChild(running, "SIGTERM");
        setTimeout(() => signalChild(running, "SIGKILL"), 1_000).unref();
      }, timeoutMs);
    }
    child.once("close", (code, signal) => {
      clearTimeout(timeout);
      children.delete(running);
      resolve({ name, code, signal, error, timedOut });
    });
  });
}

function prefixLines(stream, name, destination) {
  const lines = createInterface({ input: stream });
  lines.on("line", (line) => destination.write(`[${name}] ${line}\n`));
}

async function stopChildren(signal) {
  const running = [...children];
  if (!running.length) return;

  for (const entry of running) signalChild(entry, signal);
  const deadline = Date.now() + 5_000;
  while (children.size && Date.now() < deadline) await delay(100);
  for (const entry of [...children]) signalChild(entry, "SIGKILL");
  const killDeadline = Date.now() + 1_000;
  while (children.size && Date.now() < killDeadline) await delay(50);
}

function signalChild({ child, processGroup }, signal) {
  if (!child.pid) return;
  try {
    if (processGroup && process.platform !== "win32") process.kill(-child.pid, signal);
    else child.kill(signal);
  } catch (error) {
    if (error.code !== "ESRCH") throw error;
  }
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function fail(message) {
  const error = new Error(message);
  error.exitCode = 1;
  throw error;
}
