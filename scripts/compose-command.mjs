import { spawnSync } from "node:child_process";

import { detectContainerCommand } from "./container-command.mjs";

const selectionKey = "DEV_COMPOSE_COMMAND";
const selections = {
  "docker compose": { command: "docker", args: ["compose"], display: "docker compose" },
  "docker-compose": { command: "docker-compose", args: [], display: "docker-compose" },
  "podman compose": { command: "podman", args: ["compose"], display: "podman compose" },
  "podman-compose": { command: "podman-compose", args: [], display: "podman-compose" },
};

export function detectComposeCommand({
  cwd,
  env = process.env,
  probe = available,
  containerCommand,
} = {}) {
  const inherited = deserializeComposeCommand(env[selectionKey]);
  if (inherited) return inherited;

  const runtime = containerCommand ?? detectContainerCommand({ cwd, env, probe });
  const candidates =
    runtime === "docker"
      ? ["docker compose", "docker-compose"]
      : ["podman compose", "podman-compose"];
  for (const candidate of candidates) {
    const selection = selections[candidate];
    if (probe(selection.command, [...selection.args, "version"], cwd, env)) return selection;
  }
  const error = new Error(
    runtime === "docker"
      ? "Docker Compose was not found. Install either the `docker compose` plugin or standalone `docker-compose`."
      : "Podman Compose was not found. Install a provider for `podman compose` (podman-compose or standalone docker-compose), or install `podman-compose`.",
  );
  error.exitCode = 1;
  throw error;
}

export function serializeComposeCommand(selection) {
  return selection.display;
}

export function containerCommandForCompose(selection) {
  return selection.command.startsWith("podman") ? "podman" : "docker";
}

export function withComposeArgs(selection, args) {
  return [selection.command, [...selection.args, ...args]];
}

function deserializeComposeCommand(value) {
  return selections[value];
}

function available(command, args, cwd, env) {
  const result = spawnSync(command, args, { cwd, env, stdio: "ignore" });
  return !result.error && result.status === 0;
}
