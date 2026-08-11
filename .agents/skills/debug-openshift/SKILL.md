---
name: debug-openshift
description: Triage OpenShift failures produced by scripts/oc-deploy.sh using resource state, events, build logs, pod logs, and rollouts.
---

# Debug an OpenShift deployment

> Cluster path note: this runbook is derived from `scripts/oc-deploy.sh` and its sourced libraries;
> it has not yet been verified against a live cluster.

Read `.docs/oc-deployment.md` and confirm the current project before inspecting anything:

```bash
oc project
oc get pods,buildconfigs,builds,deployments,services,routes
oc get events --sort-by=.lastTimestamp
oc rollout status deployment/backend
```

Follow the first failed stage reported by the deployer:

- Preflight refusal: fix missing/weak `.env.production` values, wrong branch/ref, unowned name
  collisions, or OAuth/topology mismatch; do not bypass ownership labels.
- Build failure: `oc describe build/<build>` and `oc logs build/<build>`. The script builds separate
  backend and frontend images from the verified Git ref.
- Pending/crashing pod: `oc describe pod/<pod>`, `oc logs deployment/<name>`, and, for a restart,
  `oc logs deployment/<name> --previous`. Check backend migration/exact-head output and probes;
  frontend health is `/healthz`, backend health is `/api/v1/utils/health-check/`.
- Route failure: inspect `oc describe route/<name>` plus its Service endpoints. This flavor should
  expose only oauth2-proxy after staged convergence; direct backend/frontend Routes remain until
  the proxy is Ready and are then removed only when owned by this deployment.
- OAuth 401/redirect failure: compare the proxy Secret, callback/issuer values, and public Route;
  confirm backend requests still carry the private Basic credential. Do not add a browser bearer
  fallback or trust raw forwarded headers.
- Push does not build: inspect the BuildConfig webhook and the script-owned
  `webhook-access-unauthenticated` RoleBinding. The deploy summary reports inactive webhooks when
  required RBAC or a GitHub token is unavailable.
- PostgreSQL credential drift: stop. The script requires a separately confirmed owned-resource
  reset; do not delete the PVC ad hoc.

Stay read-only until the evidence identifies a fix. Apply the smallest change, rerun the command
that exposed the failure, then rerun `./scripts/oc-deploy.sh` to reconcile.
