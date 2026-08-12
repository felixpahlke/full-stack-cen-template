import { spawn, spawnSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { connect } from "node:net";
import path from "node:path";
import process from "node:process";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

import {
  detectComposeCommand,
  serializeComposeCommand,
  withComposeArgs,
} from "./compose-command.mjs";
import { detectContainerRuntime, probeViteUpstream } from "./container-runtime.mjs";
import { buildEffectiveEnvironment } from "./dev-environment.mjs";
import { configureOidcEnvironment } from "./oidc-environment.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const pnpm = process.platform === "win32" ? "pnpm.cmd" : "pnpm";
const uv = process.platform === "win32" ? "uv.exe" : "uv";
const signalExitCodes = { SIGHUP: 129, SIGINT: 130, SIGTERM: 143 };
const children = new Set();

let composeStarted = false;
let composeCommand;
let containerRuntime;
let effectiveEnv;
let fastComposeStop;
let lastSignalAt = 0;
let requestedSignal;
let signalCount = 0;
let watcher;

for (const signal of Object.keys(signalExitCodes)) {
  process.on(signal, () => handleSignal(signal));
}

let exitCode = 0;

try {
  effectiveEnv = await configureOidcEnvironment(checkEnvironment());
  composeCommand = detectComposeCommand({ cwd: root, env: effectiveEnv });
  effectiveEnv.DEV_COMPOSE_COMMAND = serializeComposeCommand(composeCommand);
  await required(process.execPath, ["scripts/check-ports.mjs"], "ports");

  composeStarted = true;
  const composeServices = ["db", "adminer"];
  if (effectiveEnv.DEV_OIDC_USES_DEX === "true") composeServices.push("dex");
  composeServices.push("oauth2-proxy");
  await requiredCompose(["up", "-d", "--wait", ...composeServices], "compose");
  await waitForTcp(Number(effectiveEnv.DB_PORT), "PostgreSQL");
  await waitForHttp(Number(effectiveEnv.ADMINER_PORT), "Adminer");
  if (effectiveEnv.DEV_OIDC_USES_DEX === "true") {
    await waitForHttp(
      Number(effectiveEnv.DEX_PORT),
      "Dex",
      "/dex/.well-known/openid-configuration",
    );
  }
  await waitForHttp(Number(effectiveEnv.OAUTH2_PROXY_PORT), "oauth2-proxy", "/ping");
  watcher = startClientWatcher();
  const apiPort = effectiveEnv.API_PORT;
  const webPort = effectiveEnv.WEB_PORT;
  effectiveEnv.VITE_API_URL = "";

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
        "127.0.0.1",
        "--port",
        apiPort,
      ],
      { processGroup: true },
    ),
    run(
      "frontend",
      pnpm,
      [
        "--filter",
        "frontend",
        "run",
        "dev",
        "--host",
        "0.0.0.0",
        "--port",
        webPort,
        "--strictPort",
      ],
      { processGroup: true },
    ),
  ];

  await waitForHttp(Number(webPort), "Vite");
  probeViteUpstream({
    runtime: containerRuntime,
    port: Number(webPort),
    cwd: root,
    env: effectiveEnv,
  });
  console.log(
    `[health] Vite upstream is reachable from a ${containerRuntime.displayName} container at ` +
      `${containerRuntime.upstreamHost}:${webPort}`,
  );

  console.log(`
Development ready

  Application  http://localhost:${effectiveEnv.OAUTH2_PROXY_PORT}
  API          http://127.0.0.1:${apiPort}
  Vite         http://localhost:${webPort}
  Adminer      http://localhost:${effectiveEnv.ADMINER_PORT}
  OIDC issuer  ${effectiveEnv.DEV_OIDC_ISSUER_URL}

  Press Ctrl+C to stop
`);

  const first = await Promise.race(servers);
  exitCode = first.code ?? signalExitCodes[first.signal] ?? 1;
  if (!requestedSignal) {
    const detail = first.error ? `: ${first.error.message}` : "";
    console.error(`\n✗ ${first.name} exited unexpectedly${detail}.`);
    await stopChildren();
  }
  await Promise.all(servers);
} catch (error) {
  exitCode = error.exitCode ?? 1;
  if (!requestedSignal) console.error(`\n✗ ${error.message}`);
} finally {
  watcher?.close();
  await stopChildren();
  if (composeStarted) {
    console.log("\nStopping development services…");
    const result = fastComposeStop ? await fastComposeStop : await stopCompose(false);
    if (fastComposeStop) await fastComposeStop;
    if (result.code !== 0 && exitCode === 0) exitCode = result.code ?? 1;
  }
}

process.exitCode = requestedSignal ? signalExitCodes[requestedSignal] : exitCode;

function checkEnvironment() {
  const environment = buildEffectiveEnvironment(root);

  const [nodeMajor, nodeMinor] = process.versions.node.split(".").map(Number);
  if (nodeMajor < 20 || (nodeMajor === 20 && nodeMinor < 19)) {
    fail(`Node 20.19 or newer is required (found ${process.versions.node}).`);
  }

  checkCommand(
    pnpm,
    ["--version"],
    "pnpm",
    "Run `corepack enable pnpm`, then `pnpm install` from the repository root.",
    environment,
  );
  checkCommand(
    uv,
    ["--version"],
    "uv",
    "Install uv, then run `uv sync --project backend`.",
    environment,
  );

  containerRuntime = detectContainerRuntime({ cwd: root, env: environment });
  environment.DEV_CONTAINER_RUNTIME = containerRuntime.id;
  environment.DEV_PROXY_UPSTREAM_HOST = containerRuntime.upstreamHost;
  environment.DEV_PROXY_EXTRA_HOST_MAPPING =
    containerRuntime.extraHosts[0] ?? "dev-proxy-noop.invalid:127.0.0.1";
  console.log(
    `[runtime] Detected ${containerRuntime.displayName}; proxy upstream host ` +
      `${containerRuntime.upstreamHost}`,
  );
  const venvPython =
    process.platform === "win32"
      ? path.join(root, "backend", ".venv", "Scripts", "python.exe")
      : path.join(root, "backend", ".venv", "bin", "python");
  if (!existsSync(venvPython)) {
    fail("Backend dependencies are missing. Run `uv sync --project backend`.");
  }

  const vite = path.join(root, "frontend", "node_modules", ".bin", "vite");
  if (!existsSync(vite)) {
    fail("Frontend dependencies are missing. Run `pnpm install` from the repository root.");
  }
  return environment;
}

function checkCommand(command, args, label, advice, environment) {
  const result = spawnSync(command, args, { env: environment, stdio: "ignore" });
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
    activeRegeneration = run("client", pnpm, ["run", "generate-client"], {
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
  fail(
    `${label} did not become reachable on port ${port}. Run \`${composeCommand.display} logs\`.`,
  );
}

async function waitForHttp(port, label, pathname = "/") {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    if (requestedSignal) fail("Development startup was interrupted.");
    try {
      const response = await fetch(`http://127.0.0.1:${port}${pathname}`, {
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
  fail(`${label} did not answer on port ${port}. Run \`${composeCommand.display} logs\`.`);
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
  if (requestedSignal) fail("Development startup was interrupted.");
  const result = await run(label, command, args, { processGroup: true });
  if (result.error) throw result.error;
  if (result.code !== 0) {
    const error = new Error(`${label} failed.`);
    error.exitCode = result.code ?? signalExitCodes[result.signal] ?? 1;
    throw error;
  }
}

async function requiredCompose(args, label) {
  const [command, commandArgs] = withComposeArgs(composeCommand, args);
  await required(command, commandArgs, label);
}

function run(name, command, args, { processGroup = false, timeoutMs } = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: root,
      stdio: ["ignore", "pipe", "pipe"],
      detached: processGroup && process.platform !== "win32",
      env: effectiveEnv ?? process.env,
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

async function stopChildren() {
  const targets = [...children];
  if (!targets.length) return;

  for (const entry of targets) signalChild(entry, "SIGINT");
  const deadline = Date.now() + 5_000;
  while (targets.some((entry) => children.has(entry)) && Date.now() < deadline) {
    await delay(100);
  }
  for (const entry of targets.filter((entry) => children.has(entry))) {
    signalChild(entry, "SIGKILL");
  }
  const killDeadline = Date.now() + 500;
  while (targets.some((entry) => children.has(entry)) && Date.now() < killDeadline) {
    await delay(50);
  }
}

function handleSignal(signal) {
  const now = Date.now();
  if (now - lastSignalAt < 250) return;
  lastSignalAt = now;
  requestedSignal ??= signal;
  signalCount += 1;
  if (signalCount === 1) {
    void stopChildren();
    return;
  }

  for (const entry of [...children]) signalChild(entry, "SIGKILL");
  if (composeStarted && !fastComposeStop) fastComposeStop = stopCompose(true);
}

function stopCompose(fast) {
  const [command, args] = withComposeArgs(composeCommand, ["down", "--timeout", fast ? "0" : "1"]);
  return run("compose", command, args, {
    processGroup: true,
    timeoutMs: fast ? 2_000 : 5_000,
  });
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
