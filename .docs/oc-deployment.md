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
`_GITHUB_TOKEN` and `_DEPLOYMENT_BRANCH_FILTER` are optional; the GitHub host is derived from
`_GIT_SSH_URL`. Use `OAUTH2_PROXY_COOKIE_SECURE=true` and real, strong
cookie/client/upstream secrets; placeholders are refused. Keep migrate-on-start enabled and
configure its lock timeout. A migration or exact-head failure prevents readiness.

When `_DEPLOYMENT_BRANCH_FILTER` is blank, the script resolves it to `oauth-proxy`, prints it, and
verifies that branch through the configured deploy key before creating either BuildConfig.

Read-only collision/direct-ingress preflight runs before mutation. The script makes backend and
frontend Ready, makes the proxy Ready, applies proxy Service/Route, and only then removes owned
direct Routes. Weighted alternate backends and numeric target ports are preserved during the
transition. `/oauth2/sign_out` ends the proxy cookie but cannot terminate upstream IdP SSO.

When the configured OpenShift project already exists, the script shows it and asks for a single
`y/N` confirmation. Fresh projects are created directly from the environment configuration.
`--reset-prod-db` is separately confirmed and deletes only the exact owned PostgreSQL resource set.
`--regenerate-ssh-key` rotates the deploy key. Run `pnpm run test:deploy` before script changes.

Running PostgreSQL `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` values are compared
before the shared application secret changes. Drift requires typed destructive confirmation and an
owned PVC reset; declining leaves both sides untouched.

The deployer owns the `webhook-access-unauthenticated` RoleBinding from
`system:unauthenticated` to `system:webhook`. Creating it requires permission both to create a
RoleBinding in the project and to bind the `system:webhook` ClusterRole. Project-scoped users on
managed clusters may need a cluster administrator to apply it:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: webhook-access-unauthenticated
  labels:
    app.kubernetes.io/managed-by: cen-template
    app.kubernetes.io/instance: <APP_NAME>
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:webhook
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:unauthenticated
```

Apply that manifest with `oc -n <PROJECT_NAME> apply -f rolebinding.yaml`. This deliberately lets
unauthenticated GitHub POST requests reach OpenShift build webhooks; the random secret embedded in
each BuildConfig webhook URL is what authenticates and protects the trigger. If the deployer lacks
the required RBAC permission, application deployment continues but the summary reports webhooks as
inactive and prints the credential-bearing URLs only on the interactive terminal. Until an
administrator creates the binding, GitHub pushes do not trigger builds. Other RoleBinding apply
errors and GitHub API failures remain fatal. Without a GitHub token, usable credential-bearing
webhook URLs are likewise terminal-only.

## Ownership and cleanup

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. Same-name resources without both labels are never
adopted. Cleanup rechecks immediately before deletion, removes only obsolete owned resources,
preserves the PVC during normal convergence, and leaves other instances untouched. Secrets use
mode-0600 temporary files and are never passed as command-line values.

### One-time legacy adoption

Use `--adopt-legacy-resources` only for a project created by the pre-ownership deployer. It verifies
exact application fingerprints, prints the precise unlabeled set, refuses partial labels or
ambiguity, and applies both labels only after the separate phrase
`adopt <PROJECT_NAME>/<APP_NAME>`. Without the flag and phrase it cannot run. Back up PostgreSQL
first; adoption itself does not reset it.

The registry gate needs `get` on the registry config, `get`/`watch` on the image-registry
Deployment, and `get` on its Endpoints. Missing only those reads warns and skips the gate; readable
unreadiness still fails. `--show-env-values` is terminal-only and refuses non-interactive use.

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
9. The registry gate succeeds with documented reads, warns when only those reads are unavailable,
   and fails on genuine unreadiness without patching operator state.
10. Deploy keys, webhook RBAC, automatic hooks, and terminal-only manual URLs produce successful
    deliveries without exposing credentials to logs.
11. Database deployment preserves the PVC; credential drift stops before secret replacement;
    confirmed reset removes only the exact owned resources.
12. In a shared namespace/project, `app-a` cannot mutate or delete `app-b`.
13. OAuth login/logout, secure cookies, forwarded identity headers, and the private Basic Auth
    proxy/backend seam work end to end.
14. Backend-only branches create no frontend resources; the no-database branch preserves any
    existing PVC for recovery.
15. Legacy adoption labels only its printed fingerprinted set after the typed adoption phrase.
16. Both BuildConfigs use the printed, remotely verified `oauth-proxy` ref.
