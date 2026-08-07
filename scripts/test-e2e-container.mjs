import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const lock = JSON.parse(readFileSync(new URL("../frontend/package-lock.json", import.meta.url)));
const version = lock.packages["node_modules/@playwright/test"].version;
const image = process.env.PLAYWRIGHT_IMAGE || `mcr.microsoft.com/playwright:v${version}-noble`;

const result = spawnSync(
  "docker",
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
    image,
    "npx",
    "playwright",
    "test",
  ],
  { cwd: root, stdio: "inherit" },
);

if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
