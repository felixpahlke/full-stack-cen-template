# Deployment scripts

This checkout deploys the fixed `oauth-proxy` topology: backend, nginx frontend, PostgreSQL, and
oauth2-proxy. `scripts/deploy-flavor.conf` is authoritative; topology overrides are refused.

```bash
cp .env.production.example .env.production
pnpm deploy:oc --dry-run
pnpm deploy:ce --dry-run
pnpm run test:deploy
```

An existing deployment project requires a single `y/N` confirmation; a fresh project is created
directly from the environment configuration. Both deployers own a resource only when both labels
match:

```text
app.kubernetes.io/managed-by=cen-template
app.kubernetes.io/instance=<APP_NAME>
```

Same-name unowned resources are never adopted. Cleanup rechecks labels immediately before
deletion, preserves the PostgreSQL PVC during normal convergence, and leaves other instances
untouched. Secret values use mode-0600 files, never command arguments, and secrets are recreated
exactly.

OAuth2-proxy is digest-pinned. Backend/frontend application workloads become project-private in
Code Engine before other mutations. On OpenShift, backend/frontend and proxy readiness precede
proxy ingress; owned direct Routes are removed only after the switch. The private
`OAUTH2_PROXY_UPSTREAM_PASSWORD` is generated when absent or set to the documented generation
marker; arbitrary placeholders and weak values are refused.

Local development resolves the optional external-issuer contract before Compose starts. Blank
`OAUTH2_PROXY_OIDC_ISSUER_URL` selects Dex; otherwise
`scripts/oidc-environment.mjs` loads the configured well-known document and supplies the current
oauth2-proxy endpoint flags. This is development-only and does not change deployment scripts.

Blank OpenShift branch filters resolve to `oauth-proxy`, are printed, and must exist remotely before
BuildConfig creation. `--adopt-legacy-resources` verifies and prints a legacy set, then requires
`adopt <PROJECT_NAME>/<APP_NAME>` before applying both ownership labels. Webhooks include the owned
unauthenticated `system:webhook` RoleBinding. Missing permission to create the binding or bind its
ClusterRole disables webhooks without failing application deployment; other apply failures and
GitHub API failures remain fatal. Usable manual URLs are terminal-only. PostgreSQL credential drift
stops before secret replacement and requires typed reset confirmation. Registry readiness skips
only when the required cluster reads are unavailable.

Code Engine persists an absolute `VITE_API_URL`, merged CORS, redirect, and well-known URLs after
nginx/Dockerfile preflight. Owned registry credentials may be reused without `_IAM_API_KEY`; setting
the key rotates them. Application-scoped image names prevent cross-application tag collisions.
Fresh projects are created automatically and wait for readiness before selection.
`--show-env-values` is terminal-only.

See [Code Engine](../.docs/ce-deployment.md) and [OpenShift](../.docs/oc-deployment.md).
