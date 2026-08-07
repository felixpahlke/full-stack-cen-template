# OpenShift deployment — backend-only

This branch deploys PostgreSQL and one backend image. It creates no frontend or OAuth resources.

## Configure and deploy

Install `oc`, Docker, and Git; log in to the intended cluster. A GitHub token is optional for
deploy-key/webhook automation.

```bash
cp .env.production.example .env.production
./scripts/oc-deploy.sh --dry-run
./scripts/oc-deploy.sh
```

Set `PROJECT_NAME`, `ENVIRONMENT=production`, `API_KEY`, `BACKEND_CORS_ORIGINS`, all five
`POSTGRES_*` values, `_APP_NAME`, and `_GIT_SSH_URL`. GitHub host/token and branch filter are
optional. Keep migrate-on-start enabled; migration lock timeout or exact-head mismatch prevents
readiness.

A blank branch filter resolves to `backend-only`, is printed, and must resolve through the deploy
key before the backend BuildConfig is created.

The deployer requires exact target confirmation. `--reset-prod-db` requires a second confirmation
and deletes only the exact owned PostgreSQL resource set. `--regenerate-ssh-key` rotates the key.

Running PostgreSQL database, user, and password values are compared before the shared secret is
replaced. Drift requires typed destructive confirmation and an owned PVC reset. The deployer owns
the `system:unauthenticated` → `system:webhook` RoleBinding; webhook API failures are fatal and
tokenless usable URLs are terminal-only.

## Ownership and cleanup

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. Same-name resources without both labels are never
adopted. Cleanup rechecks labels immediately before deletion, preserves the PVC during normal
convergence, leaves other instances untouched, and ensures no frontend resources are created.
Secrets use mode-0600 files and never command arguments.

### One-time legacy adoption

`--adopt-legacy-resources` verifies the exact old backend resource set in an existing project,
prints it, refuses partial labels or ambiguity, and applies both ownership labels only after
`adopt <PROJECT_NAME>/<APP_NAME>`. Back up PostgreSQL first; adoption itself does not reset it.

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
11. Credential drift stops before secret replacement; typed reset removes only owned DB resources.
12. In a shared namespace/project, `app-a` cannot mutate or delete `app-b`.
13. OAuth login/logout, secure cookies, forwarded identity headers, and the private Basic Auth
    proxy/backend seam work end to end.
14. Backend-only branches create no frontend resources; the no-database branch preserves any
    existing PVC for recovery.
15. Legacy adoption labels only the printed fingerprinted set after the separate phrase.
16. The backend BuildConfig uses the printed, remotely verified `backend-only` ref.

OAuth/frontend items are cross-branch release checks; this topology proves the absence half of
item 14.
