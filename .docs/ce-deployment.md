# Code Engine deployment — oauth-proxy

This branch deploys separate backend/frontend images behind a public oauth2-proxy. PostgreSQL is
external to Code Engine. Backend and frontend applications are project-private from creation.

## Configure and deploy

Install Docker or Podman, `ibmcloud` with Code Engine/Container Registry plugins, and `kubectl`;
log in to the intended account. Then:

```bash
cp .env.production.example .env.production
./scripts/ce-deploy.sh --dry-run
./scripts/ce-deploy.sh
```

Set `PROJECT_NAME`, `ENVIRONMENT=production`, all five `POSTGRES_*` values,
`BACKEND_CORS_ORIGINS`, `OAUTH2_PROXY_COOKIE_SECRET`, `OAUTH2_PROXY_CLIENT_ID`,
`OAUTH2_PROXY_CLIENT_SECRET`, `OAUTH2_PROXY_OIDC_ISSUER_URL`,
`OAUTH2_PROXY_UPSTREAM_PASSWORD`, and `OAUTH2_PROXY_COOKIE_SECURE=true`. Weak proxy secrets are
refused. The documented upstream-password generation marker is replaced with a strong value;
arbitrary placeholders are refused. The upstream password is the private Basic credential shared
only by proxy and backend.

Set `_APP_NAME`, `_IBM_CLOUD_RESOURCE_GROUP`, `_IBM_CLOUD_REGION`, `_CE_PROJECT_NAME`, and
`_CR_REGISTRY`; account name and registry namespace are optional constraints. `_IAM_API_KEY` is
required when creating or rotating the registry secret; an existing correctly owned secret can be
reused without it. Keep `MIGRATE_ON_START=true` and choose a migration lock timeout. Exact Alembic-head
verification runs before readiness; failure means the release must not serve traffic.

The deployer first makes existing owned application workloads project-private (or proves them
absent), then builds images and reconciles secrets/workloads, and exposes only oauth2-proxy.
OAuth2-proxy is digest-pinned. Proxy logout ends the proxy session but not upstream IdP SSO, so a
new login can be silent.

Before cloud mutation, the deployer validates the nginx fallback and every active Vite Dockerfile
`ARG`. It persists the absolute proxy-backed `VITE_API_URL`, merged `BACKEND_CORS_ORIGINS`, OAuth
redirect, and well-known URL in mode-0600 `.env.production`. Public entry and redirect URLs appear
in the summary; private workloads remain hidden. Fresh projects are created automatically and
polled until readable before selection; their workloads are project-only from creation.
Application-scoped image names remain an intentional isolation property. `--show-env-values` is
terminal-only and refuses non-interactive use.

## Ownership and cleanup

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. A same-name resource without both labels is left alone
and causes fail-closed collision handling. Cleanup rechecks labels immediately before deletion,
touches only obsolete resources in this topology, and preserves database storage during normal
convergence. Secret values travel through mode-0600 files, never command arguments.

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
15. Persisted Vite, CORS, redirect, and well-known values match the public proxy URL, while private
    workload URLs remain absent from the summary.
16. OAuth project absence fails before creation, and the documented seam marker is generated while
    arbitrary placeholders fail before cloud work.
