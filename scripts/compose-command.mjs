import { spawnSync } from "node:child_process";

const selectionKey = "DEV_COMPOSE_COMMAND";

export function detectComposeCommand({ cwd, env = process.env, probe = available } = {}) {
  const inherited = deserializeComposeCommand(env[selectionKey]);
  if (inherited) return inherited;

  if (probe("docker", ["compose", "version"], cwd, env)) {
    return { command: "docker", args: ["compose"], display: "docker compose" };
  }
  if (probe("docker-compose", ["version"], cwd, env)) {
    return { command: "docker-compose", args: [], display: "docker-compose" };
  }
  const error = new Error(
    "Docker Compose was not found. Install either the `docker compose` plugin or standalone `docker-compose`.",
  );
  error.exitCode = 1;
  throw error;
}

export function serializeComposeCommand(selection) {
  return selection.args.length ? "docker compose" : "docker-compose";
}

export function withComposeArgs(selection, args) {
  return [selection.command, [...selection.args, ...args]];
}

function deserializeComposeCommand(value) {
  if (value === "docker compose") {
    return { command: "docker", args: ["compose"], display: value };
  }
  if (value === "docker-compose") return { command: value, args: [], display: value };
}

function available(command, args, cwd, env) {
  const result = spawnSync(command, args, { cwd, env, stdio: "ignore" });
  return !result.error && result.status === 0;
}
