---
name: cen-template-maintenance
description: Use when maintaining this repository across its flavor branches, propagating changes from local-auth into the other flavors, resolving flavor-specific merge conflicts, or deciding which UI/auth/backend behavior each branch must preserve.
---

# CEN Template Maintenance

Use this skill for template maintenance, flavor-branch merges, and branch-specific conflict
resolution in this repository.

## Required Workflow

- Start on `local-auth` for the canonical template change.
- Commit on `local-auth` before propagating the change.
- Merge into each target flavor with `git merge local-auth --no-commit`.
- Use flavor-branch commit messages that keep the actual change summary visible.
  - Prefer `fix: deploy custom-ui frontend on openshift flavors (backend-only)` over `merge local-auth into backend-only`.
- Resolve conflicts by preserving the target flavor, not by taking `local-auth` wholesale.
- Validate the target branch before committing.

## First Reference To Read

- Read `.docs/maintenance.md` at the start of every flavor-maintenance task.

## Flavor Guardrails

- Deployment scripts are shared template assets across flavor branches.
  - Keep the script bodies identical across flavors unless a branch truly needs a different implementation.
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

- Frontend flavors: `cd frontend && npm run typecheck`
- Backend-only flavors:
  - `backend/.venv/bin/ruff check backend/app backend/tests`
  - `backend/.venv/bin/ruff format backend/app backend/tests --check`
  - `cd backend && API_KEY=changethis12345678 TELEMETRY_ENABLED=true ./.venv/bin/pytest tests/test_telemetry.py`
- Review with `git diff --cached`
