# Code Engine deployment — local-auth-custom-ui

This branch deploys separate backend and nginx frontend images. Code Engine does not provision
PostgreSQL; provide a reachable production database. Local development remains documented in
[development.md](development.md).

## Prerequisites and configuration

Install Docker or Podman, `ibmcloud`, the Code Engine and Container Registry plugins, and
`kubectl`. Log in to the intended IBM Cloud account. Copy and edit the production example:

```bash
cp .env.production.example .env.production
```

Required application values are `PROJECT_NAME`, `ENVIRONMENT=production`,
`FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD`, `SIGNUP_ACCESS_PASSWORD`, `SECRET_KEY`,
`POSTGRES_SERVER`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, and
`POSTGRES_PASSWORD`. Set `BACKEND_CORS_ORIGINS` as appropriate. Use strong non-example secrets.

Required Code Engine values are `_IBM_CLOUD_RESOURCE_GROUP`, `_IBM_CLOUD_REGION`,
`_CE_PROJECT_NAME`, and `_CR_REGISTRY`. `_IBM_CLOUD_ACCOUNT_NAME` and `_CR_NAMESPACE` are optional
constraints. `_APP_NAME` is the resource-ownership identity.

`_IAM_API_KEY` is required to create or rotate the registry secret. Later deployments can reuse an
existing correctly owned secret without the key; supplying it rotates deliberately. Default image
names are application-scoped to avoid cross-application tag collisions.

Keep `MIGRATE_ON_START=true` for application-owned migrations and set
`MIGRATION_LOCK_TIMEOUT_SECONDS` for the maximum replica lock wait. Every backend replica checks
that the database is exactly at the bundled Alembic heads before readiness. A timeout, migration
error, or head mismatch means the release is not safe to serve and leaves readiness failing.

## Deploy

Review the plan, then deploy:

```bash
./scripts/ce-deploy.sh --dry-run
./scripts/ce-deploy.sh
```

The script asks for the exact target name before mutating cloud state. It builds and pushes
separate images and creates the backend/frontend applications. Run `pnpm run test:deploy` before
changing deployment code.

For non-OAuth frontends, the deployer always embeds an absolute Code Engine backend URL through
`VITE_API_URL`; nginx's `http://backend:8000` fallback is OpenShift-only. Before cloud mutation it
checks nginx compatibility and requires a Dockerfile `ARG` for every active `VITE_*` value. It
persists `VITE_API_URL`, merged `BACKEND_CORS_ORIGINS`, and OAuth redirect/well-known URLs in the
mode-0600 `.env.production`. Configured CORS entries are retained; backend-only deployment never
adds `*` unless it was explicitly configured.

Fresh non-OAuth projects are polled until readable before selection. OAuth intentionally requires
an existing readable project so visibility narrowing can precede registry, build, and secret
mutation. The summary reports every public application URL and the OAuth redirect where relevant;
private OAuth workload URLs remain hidden. `--show-env-values` is terminal-only and refuses
non-interactive use.

## Ownership and cleanup

The script owns a resource only when both labels match:

```text
app.kubernetes.io/managed-by=cen-template
app.kubernetes.io/instance=<APP_NAME>
```

Same-name resources missing either label are never adopted. Collisions fail closed. Cleanup
rechecks both labels immediately before deletion and touches only obsolete resources in this
branch's fixed topology. Normal cleanup preserves PostgreSQL storage and does not delete unknown,
unowned, or another application's resources. Secrets are exactly recreated from mode-0600 files;
secret values are not passed in command arguments.

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
5. Separate backend/frontend image builds, instance-scoped tags, owned registry-secret reuse and
   deliberate rotation, and registry permissions work end to end.
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
15. Non-OAuth frontends contain the persisted absolute `VITE_API_URL`, reach the CE backend, and
    preserve configured CORS; backend-only summaries show the backend URL.
16. Fresh non-OAuth project creation waits for readiness, while OAuth still refuses to create a
    project automatically.

OAuth-only checklist items are cross-branch release checks and are not exercised by this
local-auth-custom-ui topology.
