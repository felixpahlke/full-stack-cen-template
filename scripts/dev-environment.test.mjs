import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { detectComposeCommand } from "./compose-command.mjs";
import { buildEffectiveEnvironment, requiredDevEnv } from "./dev-environment.mjs";

function withEnvironment(values, callback) {
  const directory = mkdtempSync(path.join(tmpdir(), "cen-dev-env-"));
  const environment = Object.fromEntries(
    requiredDevEnv.map((key) => [key, `${key.toLowerCase()}`]),
  );
  Object.assign(environment, {
    POSTGRES_SERVER: "localhost",
    POSTGRES_PORT: "5432",
    API_PORT: "8000",
    WEB_PORT: "5173",
    DB_PORT: "5432",
    ADMINER_PORT: "8080",
    ...values,
  });
  writeFileSync(
    path.join(directory, ".env"),
    `${Object.entries(environment)
      .map(([key, value]) => `${key}=${value}`)
      .join("\n")}\n`,
  );
  try {
    callback(directory, environment);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test("repo .env values override inherited database, credential, and port values", () => {
  withEnvironment({ POSTGRES_PASSWORD: "file-password" }, (root, fileValues) => {
    const inherited = Object.fromEntries(
      requiredDevEnv.map((key) => [key, `inherited-${key.toLowerCase()}`]),
    );
    const effective = buildEffectiveEnvironment(root, inherited);

    for (const key of requiredDevEnv) assert.equal(effective[key], fileValues[key]);
  });
});

test("a remote database from .env is refused unless explicitly allowed", () => {
  withEnvironment({ POSTGRES_SERVER: "database.production.example.com" }, (root) => {
    assert.throws(
      () => buildEffectiveEnvironment(root, {}),
      /remote POSTGRES_SERVER "database\.production\.example\.com"/,
    );
    assert.equal(
      buildEffectiveEnvironment(root, { DEV_ALLOW_REMOTE_DB: "1" }).POSTGRES_SERVER,
      "database.production.example.com",
    );
  });
});

test("Compose detection falls back once to standalone docker-compose", () => {
  const probes = [];
  const selection = detectComposeCommand({
    env: {},
    probe(command, args) {
      probes.push([command, ...args].join(" "));
      return command === "docker-compose";
    },
  });

  assert.deepEqual(probes, ["docker compose version", "docker-compose version"]);
  assert.deepEqual(selection, {
    command: "docker-compose",
    args: [],
    display: "docker-compose",
  });
});
