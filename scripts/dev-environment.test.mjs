import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { buildEffectiveEnvironment, requiredDevEnv } from "./dev-environment.mjs";

function withEnvironment(values, callback) {
  const directory = mkdtempSync(path.join(tmpdir(), "cen-dev-env-"));
  const environment = Object.fromEntries(
    requiredDevEnv.map((key) => [key, `${key.toLowerCase()}-from-file`]),
  );
  Object.assign(environment, values);
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

test("repo .env values override inherited application and port values", () => {
  withEnvironment({}, (root, fileValues) => {
    const inherited = Object.fromEntries(
      requiredDevEnv.map((key) => [key, `${key.toLowerCase()}-from-shell`]),
    );

    const effective = buildEffectiveEnvironment(root, inherited);

    for (const key of requiredDevEnv) assert.equal(effective[key], fileValues[key]);
  });
});

test("missing .env gives actionable setup advice", () => {
  const directory = mkdtempSync(path.join(tmpdir(), "cen-dev-env-"));
  try {
    assert.throws(() => buildEffectiveEnvironment(directory, {}), /Copy \.env\.example to \.env/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("missing required values are reported together", () => {
  withEnvironment({ API_KEY: "", API_PORT: "" }, (root) => {
    assert.throws(
      () => buildEffectiveEnvironment(root, {}),
      /Missing required \.env keys: API_KEY, API_PORT/,
    );
  });
});
