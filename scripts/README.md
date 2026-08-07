# Deployment scripts

This checkout deploys the fixed `oauth-proxy` topology: backend, nginx frontend, PostgreSQL, and
oauth2-proxy. `scripts/deploy-flavor.conf` is authoritative; topology overrides are refused.

```bash
cp .env.production.example .env.production
./scripts/oc-deploy.sh --dry-run
./scripts/ce-deploy.sh --dry-run
npm run test:deploy
```

Both deployers require exact target confirmation and own a resource only when both labels match:

```text
app.kubernetes.io/managed-by=cen-template
app.kubernetes.io/instance=<APP_NAME>
```

Same-name unowned resources are never adopted. Cleanup rechecks labels immediately before
deletion, preserves the PostgreSQL PVC during normal convergence, and leaves other instances
untouched. Secret values use mode-0600 files, never command arguments, and secrets are recreated
exactly.

OAuth2-proxy is digest-pinned. Backend/frontend application workloads become project-private in
Code Engine before other mutations. On OpenShift, backend/frontend and proxy readiness precede
proxy ingress; owned direct Routes are removed only after the switch. The private
`OAUTH2_PROXY_UPSTREAM_PASSWORD` is generated when absent but all documented placeholder or weak
values are refused.

See [Code Engine](../.docs/ce-deployment.md) and [OpenShift](../.docs/oc-deployment.md).
