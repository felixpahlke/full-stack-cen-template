# Working conventions

This is the stateless backend-only, API-key flavour of the FastAPI template. Preserve its
container-free development path and backend-only production image.

## Repository map

- `package.json` exposes the supported root commands; `scripts/` contains development,
  verification, image-build, and deployment automation.
- `backend/app/models.py` contains API models, `backend/app/api/routes/` contains endpoints, and
  `backend/app/core/config.py` contains settings; reusable business logic stays outside routes.
- Backend tests live in `backend/app/tests/` and `backend/tests/`; there is no frontend, database,
  Alembic, or Compose configuration.
- `.docs/` contains detailed development, maintenance, and deployment guides.
- `.agents/skills/` contains task-specific workflows.

## Invariants

- Preserve API-key authentication. Do not add browser bearer-token or proxy identity surfaces.
- Keep the branch free of frontend, database, Compose, Alembic, persistence packages, local users,
  and ownership models.
- Keep API models in `backend/app/models.py`, thin routes in `backend/app/api/routes/`, registration
  in `backend/app/api/main.py`, and reusable business logic outside routes.
- Keep settings in `backend/app/core/config.py`, mirror environment keys in `.env.example`, and
  never hardcode credentials or permit example/weak secrets.
- Only health checks belong outside the API-key-protected router.
- Do not introduce generated-client, route-tree, Playwright, or frontend files.
- Use pnpm only and exact-pin direct dependencies.

## Verification

Use focused checks while developing. Before handing off a completed change, run `pnpm verify`;
normal verification must remain container-free. When the production image changes, also run
`pnpm build` with a working container runtime.

## Task workflows

Use the matching repository skill when available. For changes intended for more than one flavour,
use `cen-template-maintenance` before editing.
