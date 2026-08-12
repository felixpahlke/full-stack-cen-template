# Code Engine deployment — backend-only-no-db

This branch deploys one backend image. It creates no frontend, database, migration job, or OAuth
resource.

## Configure and deploy

Install Docker or Podman, `ibmcloud` with Code Engine/Container Registry plugins, and `kubectl`;
log in to the intended account.

```bash
cp .env.production.example .env.production
./scripts/ce-deploy.sh --dry-run
./scripts/ce-deploy.sh
```

If no IBM Cloud session exists, an interactive deployment starts `ibmcloud login --sso`.
An existing session for a different configured account is never logged out or replaced
automatically; switch it explicitly and rerun the deployment.

Set `PROJECT_NAME`, `ENVIRONMENT=production`, `API_KEY`, and `BACKEND_CORS_ORIGINS`. Code Engine
requires `_APP_NAME`, `_IBM_CLOUD_RESOURCE_GROUP`, `_IBM_CLOUD_REGION`, `_CE_PROJECT_NAME`, and
`_CR_REGISTRY`; account name and registry namespace are optional. `_IAM_API_KEY` is required to
create or rotate the registry secret; an existing correctly owned secret can be reused without it.
There are no `POSTGRES_*`, migration, or frontend values.

The configured CORS value is persisted without introducing `*`, and the final summary always
prints the backend URL. Fresh projects are created automatically and polled until readable before
selection. Default image names remain application-scoped intentionally. `--show-env-values` is
terminal-only and refuses non-interactive use.

## Ownership and cleanup

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. Same-name resources without both labels are never
adopted. Cleanup rechecks labels before deletion, removes only obsolete resources for this fixed
topology, and preserves any pre-existing PVC for recovery. It will not create or delete database
or frontend resources. Secrets use mode-0600 files and never command arguments.

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
5. Separate images, instance-scoped tags, owned registry-secret reuse/rotation, and permissions
   work end to end.
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
15. The summary prints the backend URL, configured CORS is preserved without implicit `*`, and a
    fresh project is selected only after readiness.

This topology directly proves item 14's absence/preservation behavior; other items are the shared
six-branch release checklist.
