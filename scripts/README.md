# Deployment scripts

This checkout deploys its fixed `local-auth-custom-ui` topology: backend, nginx frontend, and PostgreSQL.
Branch identity is read from `scripts/deploy-flavor.conf`; runtime overrides to another topology
are refused.

Use `.env.production.example` as the source for configuration:

```bash
cp .env.production.example .env.production
pnpm deploy:oc --dry-run
pnpm deploy:ce --dry-run
```

OpenShift deployment uses `pnpm deploy:oc`; Code Engine uses `pnpm deploy:ce`. Both accept
`--env-file PATH`, `--show-env-values`, and `--dry-run`.
OpenShift additionally supports `--reset-prod-db` and `--regenerate-ssh-key`. Legacy topology
flags are accepted only when they name this branch and cannot change its component set.

`--show-env-values` is terminal-only and refuses non-interactive use. OpenShift also supports the
one-time `--adopt-legacy-resources` migration mode: it requires an existing project, exact resource
fingerprints, a printed list, and `adopt <PROJECT_NAME>/<APP_NAME>` before labels change.

## Safety contract

Every managed resource must have both:

```text
app.kubernetes.io/managed-by=cen-template
app.kubernetes.io/instance=<APP_NAME>
```

An expected name without both labels is a collision: deployment fails before mutation or emits
a warning and leaves it untouched, depending on the reconciliation stage. Cleanup rechecks both
labels immediately before deletion. Normal convergence preserves the PostgreSQL PVC; the
explicit, separately confirmed reset removes only the named owned database resources.

Blank `_DEPLOYMENT_BRANCH_FILTER` resolves to `deploy-flavor.conf`, is printed, and must exist in
the configured repository before a BuildConfig is created. OpenShift hooks include an owned
`system:unauthenticated` → `system:webhook` RoleBinding. A missing permission to create that
binding or bind the ClusterRole disables webhooks without failing the application deployment;
other apply failures and GitHub API failures remain fatal. Manual credential-bearing URLs are
terminal-only.

Code Engine always persists and supplies an absolute `VITE_API_URL`, validates nginx/Dockerfile
compatibility before cloud mutation, preserves configured CORS, and reports all public application
URLs. Existing owned registry secrets can be reused without `_IAM_API_KEY`; supplying the key
rotates them. Application-scoped image names prevent cross-application tag collisions. Fresh Code
Engine projects are created automatically and wait for readiness before selection.

Secrets are written through mode-0600 temporary files, never command arguments. Application
secrets exclude deployment-only, registry, GitHub, and `VITE_*` values and are recreated to
prevent stale keys.

Run all deployment mocks with:

```bash
pnpm run test:deploy
```

See [Code Engine](../.docs/ce-deployment.md) and
[OpenShift](../.docs/oc-deployment.md) for prerequisites, production variables, and the pending
real-cluster smoke checklist.
