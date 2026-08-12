import { spawnSync } from "node:child_process";
import { connect } from "node:net";
import process from "node:process";
import { fileURLToPath } from "node:url";

import {
  containerCommandForCompose,
  detectComposeCommand,
  withComposeArgs,
} from "./compose-command.mjs";
import { buildEffectiveEnvironment } from "./dev-environment.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
let environment;
let compose;

try {
  environment = buildEffectiveEnvironment(root);
  compose = detectComposeCommand({ cwd: root, env: environment });
} catch (error) {
  fail(error.message);
}

const ports = [
  port("DB_PORT", "PostgreSQL", 5432, "db", 5432),
  port("ADMINER_PORT", "Adminer", 8080, "adminer", 8080),
  port("API_PORT", "API", 8000),
  port("WEB_PORT", "web app", 5173),
];

const byValue = new Map();
for (const entry of ports) {
  const entries = byValue.get(entry.value) ?? [];
  entries.push(entry);
  byValue.set(entry.value, entries);
}
const overlaps = [...byValue].filter(([, entries]) => entries.length > 1);
if (overlaps.length) {
  fail(
    `Configured ports overlap:\n${overlaps
      .map(([value, entries]) => `- ${value}: ${entries.map(({ env }) => env).join(", ")}`)
      .join("\n")}`,
  );
}

const postgresPort = portValue("POSTGRES_PORT", 5432);
const database = ports.find(({ env }) => env === "DB_PORT");
if (postgresPort !== database.value) {
  fail(
    `DB_PORT=${database.value} does not match POSTGRES_PORT=${postgresPort}.\n${recoveryAdvice([
      database,
      { env: "POSTGRES_PORT" },
    ])}`,
  );
}

const published = containerPublishedPorts();
const availability = await Promise.all(
  ports.map(async (entry) => {
    if (ownsPort(entry)) return { ...entry, available: true };
    const container = published.get(entry.value);
    if (container) return { ...entry, available: false, culprit: `container ${container}` };
    return { ...entry, available: await isFree(entry.value) };
  }),
);
const conflicts = availability.filter(({ available }) => !available);
if (conflicts.length) {
  fail(
    `Local ports are occupied:\n${conflicts
      .map(
        ({ env, label, value, culprit }) =>
          `- ${env}=${value} (${label})${culprit ? ` — published by ${culprit}` : ""}`,
      )
      .join("\n")}\n${recoveryAdvice(conflicts)}`,
  );
}

console.log(
  `local ports ready: ${ports.map(({ label, value }) => `${label} ${value}`).join(", ")}`,
);

function port(env, label, fallback, composeService, containerPort) {
  return {
    env,
    label,
    value: portValue(env, fallback),
    composeService,
    containerPort,
  };
}

function recoveryAdvice(entries) {
  void entries;
  return "Update the affected values in .env, then run pnpm run dev again.";
}

function portValue(env, fallback) {
  const raw = environment[env] || String(fallback);
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > 65535) {
    fail(`${env} must be an integer between 1 and 65535 (received ${JSON.stringify(raw)}).`);
  }
  return value;
}

function ownsPort({ value, composeService, containerPort }) {
  if (!composeService) return false;
  const [command, args] = withComposeArgs(compose, ["port", composeService, String(containerPort)]);
  const result = spawnSync(command, args, {
    cwd: root,
    env: environment,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  });
  return (
    result.status === 0 &&
    result.stdout
      .trim()
      .split("\n")
      .some((address) => Number(address.slice(address.lastIndexOf(":") + 1)) === value)
  );
}

// Binding is unreliable with Docker Desktop on macOS. Name published-container
// conflicts first, then use a connection probe for native processes.
function containerPublishedPorts() {
  const result = spawnSync(
    containerCommandForCompose(compose),
    ["ps", "--format", "{{.Names}}\t{{.Ports}}"],
    {
      env: environment,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    },
  );
  const map = new Map();
  if (result.status !== 0) return map;
  for (const line of result.stdout.trim().split("\n")) {
    const [name, portList = ""] = line.split("\t");
    for (const match of portList.matchAll(/:(\d+)->/g)) map.set(Number(match[1]), name);
  }
  return map;
}

function isFree(value) {
  return new Promise((resolve) => {
    const socket = connect({ host: "127.0.0.1", port: value });
    socket.unref();
    socket.once("connect", () => {
      socket.destroy();
      resolve(false);
    });
    socket.once("error", (error) => resolve(error.code === "ECONNREFUSED"));
  });
}

function fail(message) {
  console.error(`\n✗ ${message}`);
  process.exit(1);
}
