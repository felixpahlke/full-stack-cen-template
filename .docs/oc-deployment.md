# OpenShift deployment — local-auth

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

When `_DEPLOYMENT_BRANCH_FILTER` is blank, the script uses this checkout's fixed flavor branch
(`local-auth`). It prints the resolved ref and verifies that the branch exists in the configured
repository through the deploy key before creating a BuildConfig.

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

If a running in-cluster PostgreSQL instance reports a different `POSTGRES_DB`, `POSTGRES_USER`, or
`POSTGRES_PASSWORD`, deployment stops before replacing the application secret. Applying changed
initialization credentials requires typed destructive confirmation and deletes the owned
PostgreSQL PVC. Declining leaves both sides untouched.

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

### One-time legacy adoption

Deployments created by the pre-ownership script can be migrated with the deliberately explicit
`--adopt-legacy-resources` flag. The project must already exist. The deployer checks exact legacy
names and application fingerprints, prints every proposed resource, and refuses partial ownership
or ambiguity. It changes nothing until the operator types
`adopt <PROJECT_NAME>/<APP_NAME>`. Without both the flag and that phrase, adoption is impossible.
Back up PostgreSQL first.

The integrated-registry gate requires `get` on the registry config, `get`/`watch` on the
`image-registry` Deployment, and `get` on its Endpoints in `openshift-image-registry`. Missing only
those reads produces a warning and skips the gate; readable genuine unreadiness still fails.
Registry operator configuration remains administrator-owned.

`--show-env-values` writes values directly to the interactive terminal and refuses non-interactive
use, so captured deployment output stays redacted.

OAuth branches use staged ingress: backend/frontend workloads become Ready, then proxy ingress is
applied, and only then are owned direct Routes removed. That ordering is tested in mocks even
though it is not part of this local-auth topology.

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
9. The integrated-registry gate succeeds with the documented reads, warns when only those reads
   are unavailable, and fails on genuine unreadiness without patching operator state.
10. GitHub deploy keys, webhook RBAC, automatic creation, and terminal-only manual URLs produce
    successful deliveries without exposing credentials to logs.
11. Normal database deployment preserves the PostgreSQL PVC; credential drift stops before secret
    replacement; confirmed reset removes only the exact owned PostgreSQL resources.
12. In a shared namespace/project, `app-a` cannot mutate or delete `app-b`.
13. OAuth login/logout, secure cookies, forwarded identity headers, and the private Basic Auth
    proxy/backend seam work end to end.
14. Backend-only branches create no frontend resources; the no-database branch preserves any
    existing PVC for recovery.
15. Legacy adoption labels only the printed, fingerprinted set after the separate typed phrase and
    refuses an ambiguous same-name object.
16. The printed source ref exists remotely and both BuildConfigs clone that exact ref.

OAuth-only checklist items are cross-branch release checks and are not exercised by this
local-auth topology.
