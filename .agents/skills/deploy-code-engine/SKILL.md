---
name: deploy-code-engine
description: Deploy this branch to IBM Cloud Code Engine through scripts/ce-deploy.sh using locally built images and verify the resulting applications.
---

# Deploy to Code Engine

> Cluster path note: this runbook is derived from `scripts/ce-deploy.sh`; it has not yet been
> verified against a live cluster.

Read `.docs/ce-deployment.md`, `.env.production.example`, and `scripts/deploy-flavor.conf` first.
This script builds images locally with Docker or Podman, pushes them to IBM Container Registry,
automatically selects `frontend/nginx.code-engine.conf` for frontend images, then creates or updates
Code Engine applications. It does not create Code Engine build runs.

1. Require working `ibmcloud`, `kubectl`, and Docker or Podman. Confirm IBM Cloud login, account,
   region, resource group, and Code Engine project. The script installs missing `code-engine` and
   `container-registry` plugins after confirmation; `_IAM_API_KEY` is required only to create or
   rotate its registry secret and must be authorized in the configured target account and registry
   namespace.
2. Create `.env.production`, replace required placeholders, and set the `_IBM_CLOUD_*`,
   `_CE_PROJECT_NAME`, and `_CR_REGISTRY` values documented in the example. Never expose secrets
   in chat or shell history. Set an external `POSTGRES_SERVER`; the OpenShift-only `postgresql`
   service name is rejected. The OAuth path requires an existing readable Code Engine project and
   refuses to create one so visibility can fail closed before other cloud mutations.
3. Run and review:

   ```bash
   pnpm deploy:ce --dry-run
   pnpm deploy:ce
   ```

The real run confirms the target, checks ownership collisions, targets the existing project,
creates the registry namespace/secret, builds and pushes backend/frontend images, syncs secrets,
makes the application workloads project-private, and exposes the digest-pinned oauth2-proxy app.

Pass `--env-file PATH` to both commands when using a dedicated Code Engine environment file.

Verify the printed proxy URL with `ibmcloud ce application get --name oauth-proxy` and
`curl https://<proxy-url>/api/v1/utils/health-check/`; confirm backend/frontend visibility is
project-only and test OIDC sign-in. Proxy logout does not end the upstream IdP SSO session. For a
failure, switch to `debug-code-engine`.
