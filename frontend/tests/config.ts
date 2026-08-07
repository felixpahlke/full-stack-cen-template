import path from "node:path";
import process from "node:process";

try {
  process.loadEnvFile(path.resolve(import.meta.dirname, "../../.env"));
} catch {
  throw new Error("Missing root .env. Copy .env.example to .env and run npm run dev once.");
}

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing ${name} in the root .env contract.`);
  return value;
}

export const dexTestUserEmail = required("DEX_TEST_USER_EMAIL");
export const dexTestUserPassword = required("DEX_TEST_USER_PASSWORD");
export const proxyPort = required("OAUTH2_PROXY_PORT");
export const proxyUrl = process.env.PLAYWRIGHT_BASE_URL || `http://localhost:${proxyPort}`;
