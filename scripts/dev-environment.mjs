import { existsSync, readFileSync } from "node:fs";
import { isIP } from "node:net";
import path from "node:path";
import { parseEnv } from "node:util";

export const requiredDevEnv = [
  "PROJECT_NAME",
  "API_KEY",
  "POSTGRES_SERVER",
  "POSTGRES_PORT",
  "POSTGRES_DB",
  "POSTGRES_USER",
  "POSTGRES_PASSWORD",
  "API_PORT",
  "DB_PORT",
  "ADMINER_PORT",
];

export function buildEffectiveEnvironment(root, inherited = process.env) {
  const envFile = path.join(root, ".env");
  if (!existsSync(envFile)) throw failure("Missing .env. Copy .env.example to .env first.");

  let fileValues;
  try {
    fileValues = parseEnv(readFileSync(envFile, "utf8"));
  } catch (error) {
    throw failure(
      `Could not parse .env. Copy .env.example to .env and fix its syntax. (${error.message})`,
    );
  }

  const missing = requiredDevEnv.filter((key) => !fileValues[key]?.trim());
  if (missing.length) {
    throw failure(
      `Missing required .env keys: ${missing.join(", ")}. Copy them from .env.example.`,
    );
  }

  const effective = { ...inherited, ...fileValues };
  assertLocalDatabase(effective);
  return effective;
}

export function assertLocalDatabase(environment) {
  const host = environment.POSTGRES_SERVER;
  if (isLoopbackHost(host) || environment.DEV_ALLOW_REMOTE_DB === "1") return;
  throw failure(
    `Refusing to run migrations against remote POSTGRES_SERVER ${JSON.stringify(host)}. ` +
      "Set DEV_ALLOW_REMOTE_DB=1 only when that target is intentional.",
  );
}

export function isLoopbackHost(host) {
  const normalized = host
    .trim()
    .toLowerCase()
    .replace(/^\[|\]$/g, "");
  if (normalized === "localhost" || normalized.endsWith(".localhost")) return true;
  if (normalized === "::1") return true;
  return isIP(normalized) === 4 && normalized.startsWith("127.");
}

function failure(message) {
  const error = new Error(message);
  error.exitCode = 1;
  return error;
}
