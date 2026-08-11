import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { detectContainerCommand } from "./container-command.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const command = detectContainerCommand({ cwd: root, env: process.env });
const result = spawnSync(command, ["build", "-f", "backend/Dockerfile", "backend"], {
  cwd: root,
  stdio: "inherit",
});

if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
