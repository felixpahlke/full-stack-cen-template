import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { parseEnv } from "node:util";

export const requiredDevEnv = ["PROJECT_NAME", "API_KEY", "API_PORT"];

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

  return { ...inherited, ...fileValues };
}

function failure(message) {
  const error = new Error(message);
  error.exitCode = 1;
  return error;
}
