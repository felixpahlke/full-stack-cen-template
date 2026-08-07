# Deployment scripts

This checkout deploys the fixed `backend-only-no-db` topology: one backend, no frontend, no
database, and no OAuth proxy. Branch identity comes from `scripts/deploy-flavor.conf`.

```bash
cp .env.production.example .env.production
./scripts/oc-deploy.sh --dry-run
./scripts/ce-deploy.sh --dry-run
npm run test:deploy
```

Ownership requires both `app.kubernetes.io/managed-by=cen-template` and
`app.kubernetes.io/instance=<APP_NAME>`. Same-name unowned resources are never adopted. Cleanup
rechecks labels before deletion and creates no frontend/database resources. Any existing PVC is
preserved for recovery rather than deleted. Secrets use mode-0600 files, never arguments.

See [Code Engine](../.docs/ce-deployment.md) and [OpenShift](../.docs/oc-deployment.md).
