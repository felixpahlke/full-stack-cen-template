---
name: deploy-code-engine
description: Deploy this branch to IBM Cloud Code Engine through scripts/ce-deploy.sh using locally built images and verify the resulting applications.
---

# Deploy to Code Engine

> Cluster path note: this runbook is derived from `scripts/ce-deploy.sh`; it has not yet been
> verified against a live cluster.

Read `.docs/ce-deployment.md`, `.env.production.example`, and `scripts/deploy-flavor.conf` first.
This script builds images locally with Docker or Podman, pushes them to IBM Container Registry,
then creates or updates Code Engine applications. It does not create Code Engine build runs.

1. Require working `ibmcloud`, `kubectl`, and Docker or Podman. Confirm IBM Cloud login, account,
   region, resource group, and Code Engine project. The script installs missing `code-engine` and
   `container-registry` plugins after confirmation; `_IAM_API_KEY` is required only to create or
   rotate its registry secret.
2. Create `.env.production`, replace required placeholders, and set the `_IBM_CLOUD_*`,
   `_CE_PROJECT_NAME`, and `_CR_REGISTRY` values documented in the example. Never expose secrets
   in chat or shell history. Set an external `POSTGRES_SERVER`; the OpenShift-only `postgresql`
   service name is rejected by Code Engine.
3. Run and review:

   ```bash
   ./scripts/ce-deploy.sh --dry-run
   ./scripts/ce-deploy.sh
   ```

The real run confirms the target, checks ownership collisions, targets or creates the project,
creates the registry namespace/secret, builds and pushes backend/frontend images, syncs the backend
secret, and updates applications with probes and scaling limits.

Verify the printed URLs with `ibmcloud ce application get --name <name>` and
`curl https://<backend-url>/api/v1/utils/health-check/`; open the frontend and test local sign-in.
For a failure, switch to `debug-code-engine`.
