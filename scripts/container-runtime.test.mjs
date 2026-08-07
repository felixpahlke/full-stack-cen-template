import assert from "node:assert/strict";
import test from "node:test";

import { probeViteUpstream, selectContainerRuntime } from "./container-runtime.mjs";

test("Docker Desktop keeps its native host.docker.internal mapping", () => {
  assert.deepEqual(
    selectContainerRuntime({
      context: "desktop-linux",
      info: { Name: "docker-desktop", OperatingSystem: "Docker Desktop" },
      platform: "darwin",
    }),
    {
      id: "docker-desktop",
      displayName: "Docker Desktop",
      upstreamHost: "host.docker.internal",
      extraHosts: [],
    },
  );
});

test("Colima uses Lima DNS without an extra_hosts override", () => {
  assert.deepEqual(
    selectContainerRuntime({
      context: "colima",
      info: { Name: "colima", OperatingSystem: "Ubuntu" },
      platform: "darwin",
    }),
    {
      id: "colima",
      displayName: "Colima",
      upstreamHost: "host.lima.internal",
      extraHosts: [],
    },
  );
});

test("native Linux adds the daemon host-gateway mapping", () => {
  assert.deepEqual(
    selectContainerRuntime({
      context: "default",
      info: { Name: "linux-builder", OperatingSystem: "Ubuntu" },
      platform: "linux",
    }),
    {
      id: "native-linux",
      displayName: "native Linux Docker",
      upstreamHost: "host.docker.internal",
      extraHosts: ["host.docker.internal:host-gateway"],
    },
  );
});

test("the container probe failure names the runtime and selected host", () => {
  const runtime = {
    displayName: "Colima",
    upstreamHost: "wrong.lima.internal",
    extraHosts: [],
  };
  assert.throws(
    () => probeViteUpstream({ runtime, port: 5173, execute: () => ({ status: 1 }) }),
    /Vite is not reachable from a Colima container at wrong\.lima\.internal:5173/,
  );
});
