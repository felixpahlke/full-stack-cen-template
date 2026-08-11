import { spawnSync } from "node:child_process";

export function detectContainerCommand({ cwd, env = process.env, probe = available } = {}) {
  for (const command of ["docker", "podman"]) {
    if (probe(command, ["info"], cwd, env)) return command;
  }
  const error = new Error(
    "No running container runtime was found. Start Docker, Rancher Desktop, or Podman.",
  );
  error.exitCode = 1;
  throw error;
}

function available(command, args, cwd, env) {
  const result = spawnSync(command, args, { cwd, env, stdio: "ignore" });
  return !result.error && result.status === 0;
}
