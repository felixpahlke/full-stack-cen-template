import { randomBytes } from "node:crypto";
import { chmodSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { isIP } from "node:net";
import path from "node:path";
import { parseEnv } from "node:util";

export const requiredDevEnv = [
  "PROJECT_NAME",
  "POSTGRES_SERVER",
  "POSTGRES_PORT",
  "POSTGRES_DB",
  "POSTGRES_USER",
  "POSTGRES_PASSWORD",
  "API_PORT",
  "WEB_PORT",
  "DB_PORT",
  "ADMINER_PORT",
  "DEX_PORT",
  "OAUTH2_PROXY_PORT",
  "OAUTH2_PROXY_CLIENT_ID",
  "OAUTH2_PROXY_CLIENT_SECRET",
  "OAUTH2_PROXY_COOKIE_SECRET",
  "OAUTH2_PROXY_UPSTREAM_PASSWORD",
  "DEX_TEST_USER_EMAIL",
  "DEX_TEST_USER_PASSWORD",
];

const generatedSecrets = {
  OAUTH2_PROXY_CLIENT_SECRET: () => randomBytes(32).toString("hex"),
  OAUTH2_PROXY_COOKIE_SECRET: () => randomBytes(32).toString("base64"),
  OAUTH2_PROXY_UPSTREAM_PASSWORD: () => randomBytes(32).toString("hex"),
};
const secretMarker = "generate-on-first-dev-run";

export function buildEffectiveEnvironment(root, inherited = process.env) {
  const envFile = path.join(root, ".env");
  if (!existsSync(envFile)) throw failure("Missing .env. Copy .env.example to .env first.");

  generateCheckoutSecrets(envFile);

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

export function generateCheckoutSecrets(envFile) {
  let contents = readFileSync(envFile, "utf8");
  const values = parseEnv(contents);
  const generated = [];
  for (const [key, create] of Object.entries(generatedSecrets)) {
    if (values[key] !== secretMarker) continue;
    const replacement = `${key}=${create()}`;
    const line = new RegExp(`^${key}=.*$`, "m");
    if (!line.test(contents)) continue;
    contents = contents.replace(line, replacement);
    generated.push(key);
  }
  if (!generated.length) return [];
  writeFileSync(envFile, contents, { encoding: "utf8", mode: 0o600 });
  chmodSync(envFile, 0o600);
  return generated;
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
