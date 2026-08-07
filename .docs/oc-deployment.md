# OpenShift deployment — local-auth-custom-ui

This branch deploys PostgreSQL, a backend, and a separate nginx frontend image. The production
Docker topology is unchanged by the native development workflow.

## Prerequisites and configuration

Install `oc`, Docker, Git, and optionally a GitHub token for deploy-key/webhook automation. Log in
to the intended cluster and copy the production environment:

```bash
cp .env.production.example .env.production
```

Set `PROJECT_NAME`, `ENVIRONMENT=production`, `FIRST_SUPERUSER`,
`FIRST_SUPERUSER_PASSWORD`, `SIGNUP_ACCESS_PASSWORD`, `SECRET_KEY`, all five `POSTGRES_*`
values, and `BACKEND_CORS_ORIGINS`. OpenShift additionally requires `_APP_NAME` and
`_GIT_SSH_URL`; `_GITHUB_TOKEN`, `_GITHUB_HOST`, and `_DEPLOYMENT_BRANCH_FILTER` are optional.
Replace every example secret.

Set `MIGRATE_ON_START=true` and a suitable `MIGRATION_LOCK_TIMEOUT_SECONDS`. Replicas serialize
database upgrades and each verifies the exact bundled Alembic heads before readiness. A mismatch,
timeout, or failed migration deliberately prevents the backend from becoming ready.

## Deploy

```bash
./scripts/oc-deploy.sh --dry-run
./scripts/oc-deploy.sh
```

The script requires an exact target confirmation. `--reset-prod-db` is destructive, requires a
second confirmation, and targets only the named owned PostgreSQL resources. Use
`--regenerate-ssh-key` only when rotating the deploy key. Run `npm run test:deploy` before
deployment-script changes.

## Ownership and cleanup

Resources are owned only when both labels match:

```text
app.kubernetes.io/managed-by=cen-template
app.kubernetes.io/instance=<APP_NAME>
```

Same-name resources without both labels are not adopted or overwritten. Collision checks happen
before mutation; cleanup repeats the ownership check immediately before deletion. Cleanup removes
only obsolete resources for this branch, preserves the PostgreSQL PVC during normal convergence,
and leaves unknown, unowned, and other-instance resources untouched. Secrets are recreated from
mode-0600 files and are never supplied as command-line values.

OAuth branches use staged ingress: backend/frontend workloads become Ready, then proxy ingress is
applied, and only then are owned direct Routes removed. That ordering is tested in mocks even
though it is not part of this local-auth-custom-ui topology.

## Real-cluster maintainer checklist

Real Code Engine and OpenShift smoke tests are pending and remain a release blocker for a
real-cluster deployment claim. Complete and record all items:

1. Code Engine accepts `--visibility project` on create/update and its not-found response matches
   the fail-closed classifier.
2. Code Engine Kubernetes access exposes and retains both ownership labels on Knative Services
   and Secrets.
3. Existing public OAuth application workloads become project-private before an injected
   registry/build/secret failure.
4. Fresh OAuth Code Engine applications are private from creation and reachable by the public
   proxy through project-local DNS.
5. Separate backend/frontend image builds, instance-scoped tags, registry-secret recreation, and
   registry permissions work end to end.
6. OpenShift direct-to-OAuth conversion keeps the old path until proxy readiness, then switches
   ingress and removes owned direct paths.
7. Weighted `alternateBackends`, numeric ports, and primary-Route alternate clearing match the
   real Route API.
8. OpenShift resources retain both labels after BuildConfig, image-trigger, Deployment, and Route
   controllers reconcile them.
9. The integrated-registry readiness gate succeeds on a configured cluster and fails clearly
   without auto-patching an unconfigured registry.
10. GitHub deploy keys and both component webhooks work without exposing tokens or webhook
    secrets.
11. Normal database deployment preserves the PostgreSQL PVC; confirmed reset removes only the
    exact owned PostgreSQL resources.
12. In a shared namespace/project, `app-a` cannot mutate or delete `app-b`.
13. OAuth login/logout, secure cookies, forwarded identity headers, and the private Basic Auth
    proxy/backend seam work end to end.
14. Backend-only branches create no frontend resources; the no-database branch preserves any
    existing PVC for recovery.

OAuth-only checklist items are cross-branch release checks and are not exercised by this
local-auth-custom-ui topology.
