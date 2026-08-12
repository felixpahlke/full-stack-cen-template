---
name: cen-template-maintenance
description: Use when maintaining this repository across its flavor branches, propagating shared commits from local-auth into the other flavors, resolving flavor-specific conflicts, or deciding which UI/auth/backend behavior each branch must preserve.
---

# CEN Template Maintenance

Use this skill for template maintenance, cross-flavor propagation, and branch-specific conflict
resolution in this repository.

## Required Workflow

- Start on `local-auth` for the canonical template change.
- Commit on `local-auth` before propagating the change.
- Propagate only the intended canonical commit(s) to each target flavor, normally with
  `git cherry-pick`.
- Do not merge `local-auth` wholesale: the long-lived flavors were modernized independently, so a
  broad merge pulls unrelated UI and authentication history into the target.
- Use flavor-branch commit messages that keep the actual change summary visible.
  - When conflict resolution changes the patch materially, amend the commit message with the
    target flavor.
- Resolve conflicts by preserving the target flavor, not by taking `local-auth` wholesale.
- Validate the target branch before committing.

## First Reference To Read

- Read `CONTRIBUTING.md` for the branch model and PR target rules.
- Read `.docs/maintenance.md` for detailed flavor-maintenance rules.

## Flavor Guardrails

- Deployment scripts are shared template assets across flavor branches.
  - Keep the script bodies identical across flavors.
  - Prefer expressing flavor differences through `CEN_FLAVOR` / `.env.production.example` presets rather than branch-specific script edits.

- `local-auth-custom-ui` and `oauth-proxy-custom-ui`
  - keep shadcn UI
  - do not revive Carbon-only UI patterns
- `oauth-proxy` and `oauth-proxy-custom-ui`
  - preserve the OAuth-proxy auth model
  - keep the branch-specific route and backend surface
- `backend-only`
  - no frontend
  - keep backend-side flavor tracking
- `backend-only-no-db`
  - no frontend
  - no DB-backed config/routes/tests
  - keep backend-side flavor tracking

## Validation

- Frontend flavors: `cd frontend && pnpm run typecheck`
- Backend-only flavors:
  - `backend/.venv/bin/ruff check backend/app backend/tests`
  - `backend/.venv/bin/ruff format backend/app backend/tests --check`
  - `cd backend && API_KEY=changethis12345678 TELEMETRY_ENABLED=true ./.venv/bin/pytest tests/test_telemetry.py`
- Review with `git diff --cached`
