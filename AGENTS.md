# Working conventions

This is the Carbon UI, local-authentication flavour of the FastAPI/SQLModel template. Preserve its
local user and JWT model, Carbon identity, PostgreSQL backend, and separate production images.

## Repository map

- `package.json` exposes the supported root commands; `scripts/` contains development,
  generation, verification, image-build, and deployment automation.
- `backend/app/` contains SQLModel tables, API schemas, CRUD, FastAPI routes, and settings in their
  named modules; backend tests live in `backend/app/tests/`.
- `frontend/src/routes/` contains TanStack routes and `frontend/src/components/` contains UI;
  `frontend/src/client/` and `frontend/src/routeTree.gen.ts` are generated.
- `docker-compose.yml` defines development backing services; application processes run natively.
- `.docs/` contains detailed guides; `.agents/skills/` contains task-specific workflows.

## Invariants

- Keep SQLModel tables, API schemas, CRUD, routes, and settings in their existing modules. Use
  dependency injection and keep database logic out of routes.
- Preserve local user ownership and authorization boundaries. Do not replace them with proxy or
  API-key authentication.
- Keep settings in `backend/app/core/config.py`, mirror environment keys in `.env.example`, and
  never hardcode credentials or permit example/weak secrets.
- Schema startup must reach the exact bundled Alembic head, including when
  `MIGRATE_ON_START=false`.
- Protected pages stay under `frontend/src/routes/_layout`; use TanStack Query and the generated
  client for normal API data.
- Never hand-edit generated client or route-tree files; regenerate them.
- Preserve IBM Carbon and the Tailwind token bridge. Use pnpm only and exact-pin direct dependencies.

## Verification

Use focused checks while developing. Before handing off a completed change, run `pnpm verify`.
Backend tests must remain hermetic and must never use the developer database. For browser behavior,
also run the appropriate Playwright flow documented in `frontend/README.md`.

## Task workflows

Use the matching repository skill when available. For changes intended for more than one flavour,
use `cen-template-maintenance` before editing.
