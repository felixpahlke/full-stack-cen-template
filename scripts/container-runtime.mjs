import { spawnSync } from "node:child_process";
import process from "node:process";

const probeImage = "postgres:12";

export function detectContainerRuntime({
  cwd,
  env = process.env,
  platform = process.platform,
  execute = runDocker,
} = {}) {
  const contextResult = execute(["context", "show"], { cwd, env });
  const infoResult = execute(["info", "--format", "{{json .}}"], { cwd, env });
  if (contextResult.status !== 0 || infoResult.status !== 0) {
    throw failure("Docker is not running. Start Docker Desktop or your Docker-compatible runtime.");
  }

  let info;
  try {
    info = JSON.parse(infoResult.stdout.trim());
  } catch {
    throw failure(
      "Docker returned unreadable daemon information; cannot select the Vite upstream.",
    );
  }
  return selectContainerRuntime({ context: contextResult.stdout.trim(), info, platform });
}

export function selectContainerRuntime({ context, info, platform }) {
  const identity = [context, info.Name, info.OperatingSystem, ...(info.Labels || [])]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  if (/\b(colima|lima)\b/.test(identity)) {
    return {
      id: "colima",
      displayName: "Colima",
      upstreamHost: "host.lima.internal",
      extraHosts: [],
    };
  }
  if (/docker desktop|desktop-linux|docker-desktop|linuxkit/.test(identity)) {
    return {
      id: "docker-desktop",
      displayName: "Docker Desktop",
      upstreamHost: "host.docker.internal",
      extraHosts: [],
    };
  }
  if (platform === "linux") {
    return {
      id: "native-linux",
      displayName: "native Linux Docker",
      upstreamHost: "host.docker.internal",
      extraHosts: ["host.docker.internal:host-gateway"],
    };
  }

  throw failure(
    `Unsupported Docker runtime for native host services (context ${JSON.stringify(context)}). ` +
      "Use Docker Desktop, Colima, or native Docker on Linux.",
  );
}

export function probeViteUpstream({ runtime, port, cwd, env = process.env, execute = runDocker }) {
  const args = ["run", "--rm", "--pull=never", "--entrypoint", "bash"];
  for (const mapping of runtime.extraHosts) args.push("--add-host", mapping);
  args.push(
    probeImage,
    "-ceu",
    `
      for attempt in {1..20}; do
        if exec 3<>"/dev/tcp/$1/$2" 2>/dev/null; then
          printf 'GET / HTTP/1.1\\r\\nHost: %s\\r\\nConnection: close\\r\\n\\r\\n' "$1" >&3
          IFS= read -r status <&3 || true
          exec 3>&- 3<&-
          [[ "$status" == HTTP/* ]] && exit 0
        fi
        sleep 0.25
      done
      exit 1
    `,
    "vite-probe",
    runtime.upstreamHost,
    String(port),
  );

  const result = execute(args, { cwd, env, timeout: 15_000 });
  if (result.status === 0) return;
  throw failure(
    `Vite is not reachable from a ${runtime.displayName} container at ` +
      `${runtime.upstreamHost}:${port}. The selected runtime host mapping is unusable.`,
  );
}

function runDocker(args, options) {
  return spawnSync("docker", args, { ...options, encoding: "utf8" });
}

function failure(message) {
  const error = new Error(message);
  error.exitCode = 1;
  return error;
}
