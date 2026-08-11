---
name: debug-code-engine
description: Triage Code Engine deployment failures from scripts/ce-deploy.sh across local builds, registry pushes, application revisions, events, and logs.
---

# Debug a Code Engine deployment

> Cluster path note: this runbook is derived from `scripts/ce-deploy.sh`; it has not yet been
> verified against a live cluster.

Retarget exactly what `.env.production` names before inspecting applications:

```bash
ibmcloud target -g <resource-group> -r <region>
ibmcloud ce project select --name <project> --kubecfg
ibmcloud ce application list
ibmcloud ce revision list --application <application>
```

Trace the failed script stage:

- Preconditions or target failure: check `ibmcloud account show`, both required plugins,
  `kubectl`, the selected project, and the optional account-name constraint.
- Local image build/push failure: inspect the deploy transcript and rerun the failing Docker or
  Podman build/push after fixing it. The script does not create Code Engine build runs.
- Registry failure: inspect `ibmcloud cr namespace-list` and
  `ibmcloud ce registry get --name <registry-secret>`. `_IAM_API_KEY` is required for creation or
  deliberate rotation, not reuse of an owned secret.
- Revision not Ready: run `ibmcloud ce application get --name <application>`,
  `ibmcloud ce application events --name <application>`, and
  `ibmcloud ce application logs --name <application>`. Use `revision get/events/logs --name
  <revision>` for the failing immutable revision. Check image pull, secret/env validation, the
  backend migration/exact-head gate, and the configured HTTP probes.
- Wrong public path: this flavor exposes only the backend application. Compare its generated URL
  and CORS values with application details; no frontend application should exist.

Do not delete applications, revisions, or secrets during diagnosis. Fix the smallest cause and
rerun `./scripts/ce-deploy.sh` so ownership and configuration are reconciled consistently.
