import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const proxyImage =
  "quay.io/oauth2-proxy/oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561";
const proxyFlags = [
  "--pass-basic-auth=true",
  "--pass-user-headers=true",
  "--pass-authorization-header=false",
  "--set-authorization-header=false",
  "--skip-auth-strip-headers=true",
  "--cookie-secure=true",
  "--cookie-httponly=true",
  "--cookie-samesite=lax",
];

test("deployment scripts have valid Bash syntax", () => {
  const result = spawnSync(
    "bash",
    ["-n", "scripts/ce-deploy.sh", "scripts/oc-deploy.sh", "scripts/lib/75-oauth.sh"],
    { cwd: root, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
});

test("Code Engine and OpenShift use the pinned hardened proxy contract", () => {
  for (const filename of ["scripts/ce-deploy.sh", "scripts/lib/75-oauth.sh"]) {
    const text = read(filename);
    assert.match(text, new RegExp(escapeRegExp(proxyImage)));
    for (const flag of proxyFlags) assert.ok(text.includes(flag), `${filename}: ${flag}`);
    assert.ok(!text.includes("oauth2-proxy:latest"));
    assert.ok(!text.includes("--pass-authorization-header=true"));
    assert.ok(text.includes("OAUTH2_PROXY_BASIC_AUTH_PASSWORD"));
    assert.ok(text.includes("--from-env-file"));
  }
});

test("OpenShift mock stores one seam without putting it in arguments or output", () => {
  const scratch = mkdtempSync(path.join(tmpdir(), "cen-oauth-deploy-test-"));
  const seam = "mock-seam-password-0123456789abcdef";
  try {
    const result = runBash(
      `
        source scripts/lib/50-secrets.sh
        source scripts/lib/75-oauth.sh
        APP_NAME=test-app
        DEPLOY_OAUTH=true
        ENV_FILE='${scratch}/deployment.env'
        OAUTH2_PROXY_UPSTREAM_PASSWORD='${seam}'
        OAUTH2_PROXY_COOKIE_SECRET='cookie-secret-0123456789abcdef'
        OAUTH2_PROXY_CLIENT_ID='client-id'
        OAUTH2_PROXY_CLIENT_SECRET='client-secret-0123456789abcdef'
        OAUTH2_PROXY_OIDC_ISSUER_URL='https://issuer.example'
        TMPDIR='${scratch}'
        printf 'PROJECT_NAME=test\n' > "$ENV_FILE"
        print_status() { :; }
        print_success() { :; }
        print_error() { printf '%s\n' "$1" >&2; }
        add_deployment_output() { :; }
        resource_exists() { return 1; }
        oc() {
          if [[ "$1 $2" == 'get route' ]]; then
            printf 'app.example.test'
            return
          fi
          if [[ "$1 $2 $3" == 'create secret generic' ]]; then
            local secret_file=''
            for argument in "$@"; do
              [[ "$argument" != *'${seam}'* ]] || return 91
              [[ "$argument" == --from-env-file=* ]] && secret_file="\${argument#*=}"
            done
            local mode
            mode=$(stat -f '%Lp' "$secret_file" 2>/dev/null || stat -c '%a' "$secret_file")
            [[ -n "$secret_file" && "$mode" == 600 ]]
            grep -Fqx 'OAUTH2_PROXY_BASIC_AUTH_PASSWORD=${seam}' "$secret_file"
            printf 'mock secret stored\n'
          fi
        }
        create_oauth_proxy_secret
        backend_file='${scratch}/backend.env'
        write_backend_secret_env_file "$backend_file"
        grep -Fqx 'OAUTH2_PROXY_UPSTREAM_PASSWORD=${seam}' "$backend_file"
      `,
      { TMPDIR: scratch },
    );
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /mock secret stored/);
    assert.ok(!result.stdout.includes(seam));
    assert.deepEqual(result.stderr, "");
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
});

test("OpenShift mock renders the reviewed image and header flags", () => {
  const result = runBash(`
    source scripts/lib/75-oauth.sh
    APP_NAME=test-app
    print_status() { :; }
    print_success() { :; }
    resource_exists() { return 1; }
    oc() {
      if [[ "$1" == apply ]]; then cat; else return 0; fi
    }
    deploy_oauth_proxy
  `);
  assert.equal(result.status, 0, result.stderr);
  assert.ok(result.stdout.includes(`image: ${proxyImage}`));
  for (const flag of proxyFlags) assert.ok(result.stdout.includes(flag));
});

function runBash(script, env = {}) {
  return spawnSync("bash", ["-c", script], {
    cwd: root,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

function read(filename) {
  return readFileSync(path.join(root, filename), "utf8");
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
