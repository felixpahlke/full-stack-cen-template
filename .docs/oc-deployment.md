# OpenShift deployment — oauth-proxy

This branch deploys PostgreSQL, separate backend/frontend images, and oauth2-proxy. Only the proxy
remains externally reachable after staged ingress convergence.

## Configure and deploy

Install `oc`, Docker, and Git; log in to the intended cluster. A GitHub token is optional for
deploy-key and webhook automation.

```bash
cp .env.production.example .env.production
./scripts/oc-deploy.sh --dry-run
./scripts/oc-deploy.sh
```

Set `PROJECT_NAME`, `ENVIRONMENT=production`, all five `POSTGRES_*` values,
`BACKEND_CORS_ORIGINS`, all OAuth values listed in the example, `_APP_NAME`, and `_GIT_SSH_URL`.
`_GITHUB_TOKEN`, `_GITHUB_HOST`, and `_DEPLOYMENT_BRANCH_FILTER` are optional. Use
`OAUTH2_PROXY_COOKIE_SECURE=true` and real, strong cookie/client/upstream secrets; placeholders are
refused. Keep migrate-on-start enabled and configure its lock timeout. A migration or exact-head
failure prevents readiness.

Read-only collision/direct-ingress preflight runs before mutation. The script makes backend and
frontend Ready, makes the proxy Ready, applies proxy Service/Route, and only then removes owned
direct Routes. Weighted alternate backends and numeric target ports are preserved during the
transition. `/oauth2/sign_out` ends the proxy cookie but cannot terminate upstream IdP SSO.

`--reset-prod-db` is separately confirmed and deletes only the exact owned PostgreSQL resource
set. `--regenerate-ssh-key` rotates the deploy key. Run `npm run test:deploy` before script changes.

## Ownership and cleanup

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. Same-name resources without both labels are never
adopted. Cleanup rechecks immediately before deletion, removes only obsolete owned resources,
preserves the PVC during normal convergence, and leaves other instances untouched. Secrets use
mode-0600 temporary files and are never passed as command-line values.

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
