# OpenShift deployment — backend-only-no-db

This branch deploys one backend image and no database, frontend, or OAuth proxy.

## Configure and deploy

Install `oc`, Docker, and Git; log in to the intended cluster. A GitHub token is optional for
deploy-key and webhook automation.

```bash
cp .env.production.example .env.production
./scripts/oc-deploy.sh --dry-run
./scripts/oc-deploy.sh
```

Set `PROJECT_NAME`, `ENVIRONMENT=production`, `API_KEY`, `BACKEND_CORS_ORIGINS`, `_APP_NAME`,
and `_GIT_SSH_URL`. GitHub host/token and branch filter are optional. Database and migration
settings are intentionally absent. The script requires exact target confirmation and refuses a
topology override.

A blank branch filter resolves to `backend-only-no-db`, is printed, and must resolve through the
deploy key before the backend BuildConfig is created. The deployer owns the
`system:unauthenticated` → `system:webhook` RoleBinding; webhook API failures are fatal and
tokenless usable URLs are terminal-only.

## Ownership and cleanup

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. Same-name unowned resources are never adopted. Cleanup
rechecks labels before deletion, removes only obsolete owned resources, creates no
frontend/database resources, and preserves any existing PVC for recovery. Secrets use mode-0600
files and never command arguments.

### One-time legacy adoption

`--adopt-legacy-resources` verifies the exact old backend set in an existing project, prints it,
refuses partial labels or ambiguity, and applies both labels only after
`adopt <PROJECT_NAME>/<APP_NAME>`. It never adopts or deletes database/frontend resources.

The registry gate needs read access to the registry config, Deployment (`get`/`watch`), and
Endpoints. Missing only those reads warns and skips the gate; readable genuine unreadiness fails.
`--show-env-values` is terminal-only and refuses non-interactive use.

## Real-cluster maintainer checklist

Real cluster smoke tests are pending and remain a release blocker for a deployment claim:

1. Code Engine accepts `--visibility project` on create/update and its not-found response matches
   the fail-closed classifier.
2. Code Engine Kubernetes access exposes and retains both ownership labels on Knative Services
   and Secrets.
3. Existing public OAuth application workloads become project-private before an injected
   registry/build/secret failure.
4. Fresh OAuth applications are private from creation and reachable by the public proxy through
   project-local DNS.
5. Separate backend/frontend image builds, instance-scoped tags, registry-secret recreation, and
   registry permissions work end to end.
6. OpenShift direct-to-OAuth conversion keeps the old path until proxy readiness, then switches
   ingress and removes owned direct paths.
7. Weighted `alternateBackends`, numeric ports, and primary-Route alternate clearing match the
   real Route API.
8. OpenShift resources retain both labels after BuildConfig, image-trigger, Deployment, and Route
   controllers reconcile them.
9. Registry inspection warns only for missing reads and fails on genuine readable unreadiness.
10. Deploy keys, webhook RBAC, automatic hooks, and terminal-only URLs deliver without log leaks.
11. Normal database deployment preserves the PostgreSQL PVC; confirmed reset removes only the
    exact owned PostgreSQL resources.
12. In a shared namespace/project, `app-a` cannot mutate or delete `app-b`.
13. OAuth login/logout, secure cookies, forwarded identity headers, and the private Basic Auth
    proxy/backend seam work end to end.
14. Backend-only branches create no frontend resources; the no-database branch preserves any
    existing PVC for recovery.
15. Legacy adoption labels only the printed fingerprinted backend set after the separate phrase.
16. The backend BuildConfig uses the printed, remotely verified `backend-only-no-db` ref.

This topology directly proves item 14's absence/preservation behavior; other items are the shared
six-branch release checklist.
