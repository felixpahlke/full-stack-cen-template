# Working conventions

This is the backend-only, PostgreSQL, API-key flavour of the FastAPI/SQLModel template. Preserve
its frontend-free API and backend-only production image.

## Repository map

- `package.json` exposes the supported root commands; `scripts/` contains development,
  verification, image-build, and deployment automation.
- `backend/app/` contains SQLModel tables, API schemas, CRUD, FastAPI routes, and settings in their
  named modules; backend tests live in `backend/app/tests/` and `backend/tests/`.
- `docker-compose.yml` defines PostgreSQL and Adminer for development; FastAPI runs natively.
- `.docs/` contains detailed development, maintenance, and deployment guides.
- `.agents/skills/` contains task-specific workflows.

## Invariants

- Preserve API-key authentication. Do not add frontend, local users, ownership, proxy identity, or
  browser bearer-token surfaces.
- Keep SQLModel tables, API schemas, CRUD, routes, and settings in their existing modules. Use
  dependency injection and keep database logic out of routes.
- Keep settings in `backend/app/core/config.py`, mirror environment keys in `.env.example`, and
  never hardcode credentials or permit example/weak secrets.
- Schema startup must reach the exact bundled Alembic head, including when
  `MIGRATE_ON_START=false`.
- Do not introduce generated-client, route-tree, Playwright, or frontend files.
- Use pnpm only and exact-pin direct dependencies.

## Verification

Use focused checks while developing. Before handing off a completed change, run `pnpm verify`.
Backend tests must remain hermetic and must never use the developer database. When the production
image changes, also run `pnpm build` with a working container runtime.

## Task workflows

Use the matching repository skill when available. For changes intended for more than one flavour,
use `cen-template-maintenance` before editing.
