---
name: deploy-openshift
description: Deploy this branch to OpenShift through scripts/oc-deploy.sh and verify the script-managed resources and routes.
---

# Deploy to OpenShift

> Cluster path note: this runbook is derived from `scripts/oc-deploy.sh` and its sourced libraries;
> it has not yet been verified against a live cluster.

Read `.docs/oc-deployment.md`, `.env.production.example`, and `scripts/deploy-flavor.conf` first.
The deployer uses the checked-out flavor and refuses a conflicting topology override.

1. Confirm `oc` is logged into the intended cluster and that `_GIT_SSH_URL` and the deployment
   branch are reachable. Never ask for tokens or secret values in chat.
2. Create the ignored environment file and replace every required placeholder:

   ```bash
   cp .env.production.example .env.production
   ./scripts/oc-deploy.sh --dry-run
   ./scripts/oc-deploy.sh
   ```

3. Read the dry-run topology and obtain confirmation before the real command. The script confirms
   the target again, checks collisions/ownership, sets up the namespace, deploy key, integrated
   registry, secrets, the backend BuildConfig/workload, Route, and webhook. It deploys no database
   in this flavor.
4. Treat `--reset-prod-db`, `--regenerate-ssh-key`, and `--adopt-legacy-resources` as separate,
   explicitly approved recovery operations. `--show-env-values` exposes values in the terminal.

Verify the summary, then run `oc get pods,builds,deployments,services,routes` in the selected
project. Confirm no frontend resources exist. Check the backend Route and
`/api/v1/utils/health-check/`; exercise an endpoint with its API key.
For a failure, switch to `debug-openshift`.
