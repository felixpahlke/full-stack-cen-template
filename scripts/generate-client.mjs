import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const frontend = path.join(root, "frontend");
const openapi = path.join(frontend, "openapi.json");
const client = path.join(frontend, "src", "client");
const oldClient = `${client}.old`;
const staging = path.join(frontend, "generate-client-staging");
const stagedOpenapi = path.join(staging, "openapi.json");
const stagedClient = path.join(staging, "client");
const stagedTsconfig = path.join(staging, "tsconfig.json");
const lock = path.join(root, ".generate-client.lock");
const lockOwner = path.join(lock, "owner.json");
const lockToken = randomUUID();
let ownsLock = false;
const pnpm = process.platform === "win32" ? "pnpm.cmd" : "pnpm";
const uv = process.platform === "win32" ? "uv.exe" : "uv";
const check = process.argv.includes("--check");
const generatedPaths = ["frontend/src/client", "frontend/src/routeTree.gen.ts"];
let requestedSignal;
let generatedWasStale = false;

for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => {
    requestedSignal ??= signal;
  });
}

try {
  await acquireLock();
  recoverInterruptedPublish();
  const before = check ? fingerprint(generatedPaths) : undefined;
  rmSync(staging, { recursive: true, force: true });
  mkdirSync(staging);
  required(uv, [
    "run",
    "--project",
    "backend",
    "python",
    "backend/scripts/generate_openapi.py",
    "--output",
    stagedOpenapi,
  ]);
  required(pnpm, ["--filter", "frontend", "exec", "openapi-ts", "--file", "openapi-ts.config.ts"], {
    ...process.env,
    OPENAPI_INPUT: stagedOpenapi,
    OPENAPI_OUTPUT: stagedClient,
  });
  required(pnpm, ["exec", "biome", "format", "--write", stagedClient]);
  writeFileSync(
    stagedTsconfig,
    `${JSON.stringify(
      {
        extends: "../tsconfig.json",
        compilerOptions: { composite: false },
        include: ["client/**/*.ts"],
      },
      null,
      2,
    )}\n`,
  );
  required(pnpm, ["--filter", "frontend", "exec", "tsc", "--project", stagedTsconfig]);
  required(pnpm, ["--filter", "frontend", "run", "generate-routes"]);
  interrupted();
  publish();
  generatedWasStale = check && before !== fingerprint(generatedPaths);
} finally {
  rmSync(staging, { recursive: true, force: true });
  releaseLock();
}

if (generatedWasStale) {
  console.error(
    "\nGenerated client or route tree was stale and has been refreshed. " +
      "Review and commit the generated changes, then run `pnpm run check` again.",
  );
  process.exitCode = 1;
}

function required(command, args, env = process.env) {
  const result = spawnSync(command, args, { cwd: root, env, stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status ?? 1;
  if (result.signal) requestedSignal ??= result.signal;
  if (process.exitCode || requestedSignal) interrupted();
}

function interrupted() {
  if (!requestedSignal && !process.exitCode) return;
  const error = new Error(
    requestedSignal
      ? `Client generation interrupted by ${requestedSignal}.`
      : "Client generation failed.",
  );
  error.code = process.exitCode || 1;
  throw error;
}

function publish() {
  renameSync(stagedOpenapi, openapi);
  if (existsSync(client)) renameSync(client, oldClient);
  // The live path is briefly absent between these two renames. Every generation entry
  // point holds the repository lock, so no concurrent writer can enter this window.
  try {
    renameSync(stagedClient, client);
  } catch (error) {
    if (!existsSync(client) && existsSync(oldClient)) renameSync(oldClient, client);
    throw error;
  }
  rmSync(oldClient, { recursive: true, force: true });
}

function recoverInterruptedPublish() {
  if (!existsSync(oldClient)) return;
  if (existsSync(client)) {
    rmSync(oldClient, { recursive: true, force: true });
    return;
  }
  console.log("Restoring the generated client after an interrupted publication…");
  renameSync(oldClient, client);
}

async function acquireLock() {
  let announcedWait = false;
  while (true) {
    interrupted();
    try {
      mkdirSync(lock);
      ownsLock = true;
      writeFileSync(
        lockOwner,
        `${JSON.stringify({ pid: process.pid, token: lockToken, createdAt: Date.now() })}\n`,
      );
      return;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
    }

    if (removeStaleLock()) continue;
    if (!announcedWait) {
      console.log("Another client generation is active; waiting for the repository lock…");
      announcedWait = true;
    }
    await delay(100);
  }
}

function removeStaleLock() {
  let owner;
  try {
    owner = JSON.parse(readFileSync(lockOwner, "utf8"));
  } catch {
    owner = undefined;
  }
  if (owner?.pid && processIsAlive(owner.pid)) return false;
  if (!owner && Date.now() - statSync(lock).mtimeMs < 5_000) return false;
  rmSync(lock, { recursive: true, force: true });
  return true;
}

function releaseLock() {
  if (!ownsLock) return;
  try {
    const owner = JSON.parse(readFileSync(lockOwner, "utf8"));
    if (owner.token === lockToken) rmSync(lock, { recursive: true, force: true });
  } catch {}
}

function processIsAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error.code === "EPERM";
  }
}

function fingerprint(entries) {
  const hash = createHash("sha256");
  for (const entry of entries) addToFingerprint(entry, hash);
  return hash.digest("hex");
}

function addToFingerprint(relativePath, hash) {
  const absolutePath = path.join(root, relativePath);
  hash.update(relativePath);
  hash.update("\0");
  if (!existsSync(absolutePath)) {
    hash.update("missing\0");
    return;
  }
  const metadata = statSync(absolutePath);
  if (metadata.isFile()) {
    hash.update(readFileSync(absolutePath));
    return;
  }
  for (const entry of readdirSync(absolutePath).sort()) {
    addToFingerprint(path.join(relativePath, entry), hash);
  }
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
