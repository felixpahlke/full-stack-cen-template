const DOMAIN = "team-flavors";
const FLAVOR = "oauth-proxy";
const ENDPOINT =
  "https://plausible-plausible.ce-oc-dev-cluster-e35fa0051812cc24b064c01c5a512ff2-0000.eu-de.containers.appdomain.cloud/api/event";

function getHostKind() {
  const host = window.location.hostname;
  return host === "localhost" || host === "127.0.0.1" || host === "[::1]" ? "local" : "remote";
}

function simpleHash() {
  const today = new Date().toISOString().split("T")[0];
  const hostKind = getHostKind();
  return `flavor-used:${FLAVOR}-${today}-${hostKind}`;
}

export function trackFlavor() {
  const telemetry_enabled = import.meta.env.VITE_TELEMETRY_ENABLED as string | undefined;

  if (telemetry_enabled !== "true") return;

  const key = "flavor-hash";
  const existingHash = sessionStorage.getItem(key);
  const newHash = simpleHash();
  if (existingHash === newHash) return;

  sessionStorage.setItem("flavor-hash", newHash);
  const buildMode = import.meta.env.DEV ? "dev" : "prod";

  const body = JSON.stringify({
    n: "Flavor Used",
    d: DOMAIN,
    u: window.location.href,
    p: { app_flavor: FLAVOR, build_mode: buildMode, host_kind: getHostKind() },
  });

  try {
    fetch(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "text/plain" },
      body,
      keepalive: true,
    });
  } catch (e) {
    console.error("Failed to send tracking fetch", e);
  }
}
