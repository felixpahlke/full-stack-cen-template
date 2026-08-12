import assert from "node:assert/strict";
import test from "node:test";

import {
  detectContainerRuntime,
  probeViteUpstream,
  selectContainerRuntime,
} from "./container-runtime.mjs";

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
      command: "docker",
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
      command: "docker",
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
      command: "docker",
    },
  );
});

test("Podman is detected from its real info shape when context show is unsupported", () => {
  const calls = [];
  const info = {
    host: { os: "linux" },
    store: { graphDriverName: "overlay" },
    registries: {},
    plugins: {},
    version: { Version: "6.0.2" },
    Client: { Version: "6.0.2", Os: "darwin" },
  };
  const runtime = detectContainerRuntime({
    platform: "darwin",
    execute(command, args) {
      calls.push([command, ...args].join(" "));
      if (command === "docker") return { status: 1, stdout: "" };
      if (args[0] === "context") return { status: 125, stdout: "" };
      return { status: 0, stdout: JSON.stringify(info) };
    },
  });

  assert.deepEqual(calls, [
    "docker info --format {{json .}}",
    "podman info --format {{json .}}",
    "podman context show",
  ]);
  assert.deepEqual(runtime, {
    id: "podman",
    displayName: "Podman",
    upstreamHost: "host.containers.internal",
    extraHosts: [],
    command: "podman",
  });
});

test("Podman behind Docker compatibility keeps the working Docker command", () => {
  const calls = [];
  const runtime = detectContainerRuntime({
    platform: "darwin",
    execute(command, args) {
      calls.push([command, ...args].join(" "));
      if (args[0] === "info") {
        return {
          status: 0,
          stdout: JSON.stringify({ Name: "localhost.localdomain", OperatingSystem: "fedora" }),
        };
      }
      if (args[0] === "context") return { status: 0, stdout: "default\n" };
      return {
        status: 0,
        stdout: JSON.stringify({
          Components: [{ Name: "Podman Engine", Version: "5.7.1" }],
        }),
      };
    },
  });

  assert.deepEqual(calls, [
    "docker info --format {{json .}}",
    "docker context show",
    "docker version --format {{json .Server}}",
  ]);
  assert.deepEqual(runtime, {
    id: "podman",
    displayName: "Podman",
    upstreamHost: "host.containers.internal",
    extraHosts: [],
    command: "docker",
  });
});

// Rancher Desktop is Lima-based on macOS and reports a daemon name containing
// `lima`, so this fixture must keep that substring: with the Lima branch checked
// first, Rancher Desktop was misdetected as Colima and given host.lima.internal.
test("Rancher Desktop dockerd uses host.docker.internal", () => {
  assert.deepEqual(
    selectContainerRuntime({
      context: "rancher-desktop",
      info: { Name: "lima-rancher-desktop", OperatingSystem: "Alpine Linux v3.20" },
      platform: "darwin",
    }),
    {
      id: "rancher-desktop",
      displayName: "Rancher Desktop",
      upstreamHost: "host.docker.internal",
      extraHosts: [],
      command: "docker",
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
