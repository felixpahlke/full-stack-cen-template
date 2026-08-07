# Deployment scripts

This checkout deploys its fixed `local-auth-custom-ui` topology: backend, nginx frontend, and PostgreSQL.
Branch identity is read from `scripts/deploy-flavor.conf`; runtime overrides to another topology
are refused.

Use `.env.production.example` as the source for configuration:

```bash
cp .env.production.example .env.production
./scripts/oc-deploy.sh --dry-run
./scripts/ce-deploy.sh --dry-run
```

OpenShift deployment uses `./scripts/oc-deploy.sh`; Code Engine uses
`./scripts/ce-deploy.sh`. Both accept `--env-file PATH`, `--show-env-values`, and `--dry-run`.
OpenShift additionally supports `--reset-prod-db` and `--regenerate-ssh-key`. Legacy topology
flags are accepted only when they name this branch and cannot change its component set.

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

Secrets are written through mode-0600 temporary files, never command arguments. Application
secrets exclude deployment-only, registry, GitHub, and `VITE_*` values and are recreated to
prevent stale keys.

Run all deployment mocks with:

```bash
npm run test:deploy
```

See [Code Engine](../.docs/ce-deployment.md) and
[OpenShift](../.docs/oc-deployment.md) for prerequisites, production variables, and the pending
real-cluster smoke checklist.
