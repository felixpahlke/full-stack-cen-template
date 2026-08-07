# Deployment scripts

This checkout deploys the fixed `backend-only` topology: backend plus PostgreSQL, with no frontend
or OAuth proxy. Branch identity comes from `scripts/deploy-flavor.conf`; overrides are refused.

```bash
cp .env.production.example .env.production
./scripts/oc-deploy.sh --dry-run
./scripts/ce-deploy.sh --dry-run
npm run test:deploy
```

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. Same-name unowned resources are never adopted. Cleanup
rechecks labels immediately before deletion, preserves the PostgreSQL PVC during normal
convergence, and removes no frontend resources because this branch creates none. Secrets use
mode-0600 files and never command arguments.

See [Code Engine](../.docs/ce-deployment.md) and [OpenShift](../.docs/oc-deployment.md).
