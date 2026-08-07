import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, renameSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const frontend = path.join(root, "frontend");
const openapi = path.join(frontend, "openapi.json");
const client = path.join(frontend, "src", "client");
const staging = mkdtempSync(path.join(frontend, ".generate-client-"));
const stagedOpenapi = path.join(staging, "openapi.json");
const stagedClient = path.join(staging, "client");
const stagedTsconfig = path.join(staging, "tsconfig.json");
const npm = process.platform === "win32" ? "npm.cmd" : "npm";
const uv = process.platform === "win32" ? "uv.exe" : "uv";
let requestedSignal;

for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => {
    requestedSignal ??= signal;
  });
}

try {
  required(uv, [
    "run",
    "--project",
    "backend",
    "python",
    "backend/scripts/generate_openapi.py",
    "--output",
    stagedOpenapi,
  ]);
  required(npm, ["--prefix", "frontend", "run", "generate-client"], {
    ...process.env,
    OPENAPI_INPUT: stagedOpenapi,
    OPENAPI_OUTPUT: stagedClient,
  });
  required(npm, ["exec", "--", "biome", "format", "--write", stagedClient]);
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
  required(npm, ["--prefix", "frontend", "exec", "--", "tsc", "--project", stagedTsconfig]);
  required(npm, ["--prefix", "frontend", "run", "generate-routes"]);
  interrupted();
  publish();
} finally {
  rmSync(staging, { recursive: true, force: true });
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
  const backupOpenapi = path.join(staging, "openapi.backup.json");
  const backupClient = path.join(staging, "client.backup");
  let openapiBackedUp = false;
  let clientBackedUp = false;
  let openapiPublished = false;
  let clientPublished = false;

  try {
    if (existsSync(openapi)) {
      renameSync(openapi, backupOpenapi);
      openapiBackedUp = true;
    }
    if (existsSync(client)) {
      renameSync(client, backupClient);
      clientBackedUp = true;
    }
    renameSync(stagedOpenapi, openapi);
    openapiPublished = true;
    renameSync(stagedClient, client);
    clientPublished = true;
  } catch (error) {
    if (clientPublished) rmSync(client, { recursive: true, force: true });
    if (clientBackedUp) renameSync(backupClient, client);
    if (openapiPublished) rmSync(openapi, { force: true });
    if (openapiBackedUp) renameSync(backupOpenapi, openapi);
    throw error;
  }
}
