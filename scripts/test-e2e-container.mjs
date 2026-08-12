import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import process from "node:process";
import { fileURLToPath } from "node:url";

import { detectContainerRuntime } from "./container-runtime.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const frontendPackage = JSON.parse(
  readFileSync(new URL("../frontend/package.json", import.meta.url)),
);
const version = frontendPackage.devDependencies["@playwright/test"];
const image = process.env.PLAYWRIGHT_IMAGE || `mcr.microsoft.com/playwright:v${version}-noble`;
const runtime = detectContainerRuntime({ cwd: root, env: process.env });

const result = spawnSync(
  runtime.command,
  [
    "run",
    "--rm",
    "--network",
    "host",
    "--ipc=host",
    "-v",
    `${root}:/work`,
    "-w",
    "/work/frontend",
    "-e",
    "PLAYWRIGHT_EXTERNAL_SERVER=true",
    "-e",
    "PLAYWRIGHT_CONTAINER=true",
    image,
    "./node_modules/.bin/playwright",
    "test",
    ...process.argv.slice(2),
  ],
  { cwd: root, stdio: "inherit" },
);

if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
