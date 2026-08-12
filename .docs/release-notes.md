# Release notes — backend-only modernization

Uvicorn now runs natively under `pnpm run dev`; Compose contains only PostgreSQL and Adminer.
Backend tests use disposable Testcontainers databases. Startup serializes migrations and refuses
readiness unless the database is exactly at the checkout's Alembic heads.

The backend image now runs `uvicorn app.main:create_app --factory`. Compatibility `app`,
`settings`, and `engine` exports are lazy factory products rather than shells or eager globals.
Strict mypy checking is part of canonical `pnpm run check` and `pnpm run verify`.

The removed user/owner test and dependency residue does not change the live API-key item surface.
Deployment now uses two-label ownership and fail-closed collision handling. Real cluster smoke
testing is pending; both deployment guides include the 14-item maintainer checklist.

See [migration-guide.md](migration-guide.md). Rollback tag: `pre-modernization/backend-only`.
