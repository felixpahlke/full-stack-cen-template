## Maintenance and Updates to the Template

This repository uses branches as product flavors, not as short-lived feature branches.
When you maintain the template, preserve each branch's flavor identity while pulling in
the shared changes from `local-auth`.

### Canonical Workflow

1. Start on `local-auth`. This is the canonical source branch for template updates.
2. Implement and commit the generic change on `local-auth` first.
3. For every other flavor branch:
   - checkout the target branch
   - merge with `git merge local-auth --no-commit`
   - resolve conflicts by preserving the target branch's flavor
   - run branch-appropriate validation
   - commit the resolved result
4. Push the updated branches.

Do not blindly accept `local-auth` during conflict resolution. The target branch may need
to keep a different UI stack, auth model, route surface, or backend shape.

### Flavor Matrix

- `local-auth`
  - Carbon frontend
  - local authentication
  - full local-auth user/admin/settings surface
- `local-auth-custom-ui`
  - shadcn custom UI
  - local authentication
- `oauth-proxy`
  - Carbon frontend
  - OAuth proxy authentication
- `oauth-proxy-custom-ui`
  - shadcn custom UI
  - OAuth proxy authentication
- `backend-only`
  - backend plus database
  - API key auth
  - no frontend
- `backend-only-no-db`
  - backend only
  - API key auth
  - no frontend
  - no database-backed config/routes/tests

### Merge Rules Learned During Flavor Maintenance

- Preserve the target branch's UI system.
  - Carbon branches stay Carbon.
  - shadcn branches stay shadcn.
- Preserve the target branch's authentication model.
  - local-auth branches stay local-auth.
  - oauth-proxy branches stay oauth-proxy.
  - backend-only branches stay API-key-based.
- Preserve the target branch's route and API surface.
  - Do not reintroduce pages, components, or backend routes that belong only to a different flavor.
- Preserve the target branch's backend shape.
  - `backend-only` stays backend-only.
  - `backend-only-no-db` stays no-db and should not gain DB-backed config, routes, or tests.
- Never edit `frontend/src/client/` manually. If exposed backend routes change on a frontend flavor, regenerate the client with `./scripts/generate-client.sh`.

### Tracking Rules

- Frontend flavors currently use frontend-side flavor tracking.
- Backend-only flavors use backend-side startup tracking.
- Keep the telemetry toggle in env example files with this explanatory comment:
  - `We just track which flavor you're using. We want to find out, which flavors are being used.`
- For backend-only branches, keep the toggle as `TELEMETRY_ENABLED`, not `VITE_TELEMETRY_ENABLED`.

### Validation Checklist

- Frontend flavors:
  - `cd frontend && npm run typecheck`
- Backend-only flavors:
  - `backend/.venv/bin/ruff check backend/app backend/tests`
  - `backend/.venv/bin/ruff format backend/app backend/tests --check`
- Backend-only tracking test:
  - `cd backend && API_KEY=changethis12345678 TELEMETRY_ENABLED=true ./.venv/bin/pytest tests/test_telemetry.py`
- Before committing any merge resolution:
  - `git diff --cached`

### Practical Troubleshooting Notes

- The frontend container mounts source code separately from container `node_modules`. If you switch branches and suddenly get missing package import errors, the source changed but the container dependencies may not have been recreated yet.
