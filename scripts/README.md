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

Blank branch filters resolve to `backend-only-no-db` and must exist remotely before BuildConfig
creation. Legacy backend resources can be labeled only with `--adopt-legacy-resources`, matching
fingerprints, and the separate `adopt <PROJECT_NAME>/<APP_NAME>` phrase. OpenShift disables
webhooks without failing application deployment when permission to create their RoleBinding or
bind `system:webhook` is missing; other RoleBinding apply failures and GitHub API failures remain
fatal. Registry readiness skips only for missing reads.

Code Engine preserves configured CORS without adding `*`, reports the backend URL, waits for
fresh-project readiness, and reuses an owned registry secret without `_IAM_API_KEY`. App-scoped
image names are intentional. `--show-env-values` is terminal-only.

See [Code Engine](../.docs/ce-deployment.md) and [OpenShift](../.docs/oc-deployment.md).
