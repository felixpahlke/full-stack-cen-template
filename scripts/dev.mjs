import { spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

import { buildEffectiveEnvironment } from "./dev-environment.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const uv = process.platform === "win32" ? "uv.exe" : "uv";
const signalExitCodes = { SIGHUP: 129, SIGINT: 130, SIGTERM: 143 };
const children = new Set();

let effectiveEnv;
let lastSignalAt = 0;
let requestedSignal;
let signalCount = 0;

for (const signal of Object.keys(signalExitCodes)) {
  process.on(signal, () => handleSignal(signal));
}

let exitCode = 0;

try {
  effectiveEnv = checkEnvironment();
  await required(process.execPath, ["scripts/check-ports.mjs"], "ports");

  const apiPort = effectiveEnv.API_PORT;
  console.log(`\nDevelopment ready: API http://localhost:${apiPort}`);

  const backend = run(
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
  );

  const result = await backend;
  exitCode = result.code ?? signalExitCodes[result.signal] ?? 1;
  if (!requestedSignal) {
    const detail = result.error ? `: ${result.error.message}` : "";
    console.error(`\n✗ backend exited unexpectedly${detail}.`);
  }
} catch (error) {
  exitCode = error.exitCode ?? 1;
  if (!requestedSignal) console.error(`\n✗ ${error.message}`);
} finally {
  await stopChildren();
}

process.exitCode = requestedSignal ? signalExitCodes[requestedSignal] : exitCode;

function checkEnvironment() {
  const environment = buildEffectiveEnvironment(root);

  const [nodeMajor, nodeMinor] = process.versions.node.split(".").map(Number);
  if (nodeMajor < 20 || (nodeMajor === 20 && nodeMinor < 19)) {
    fail(`Node 20.19 or newer is required (found ${process.versions.node}).`);
  }

  checkCommand(
    uv,
    ["--version"],
    "uv",
    "Install uv, then run `uv sync --project backend`.",
    environment,
  );

  const venvPython =
    process.platform === "win32"
      ? path.join(root, "backend", ".venv", "Scripts", "python.exe")
      : path.join(root, "backend", ".venv", "bin", "python");
  if (!existsSync(venvPython)) {
    fail("Backend dependencies are missing. Run `uv sync --project backend`.");
  }

  return environment;
}

function checkCommand(command, args, label, advice, environment) {
  const result = spawnSync(command, args, { env: environment, stdio: "ignore" });
  if (result.error?.code === "ENOENT") fail(`${label} was not found. ${advice}`);
  if (result.status !== 0) fail(`${label} is unavailable. ${advice}`);
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

function run(name, command, args, { processGroup = false } = {}) {
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
    child.once("error", (value) => {
      error = value;
    });
    child.once("close", (code, signal) => {
      children.delete(running);
      resolve({ name, code, signal, error });
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
