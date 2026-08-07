# Working conventions

This branch is the shadcn/ui, local-authentication custom-UI variant of the template. Keep changes small,
preserve its authentication and UI identity, and use the root npm command facade.

## Development

Prerequisites are Node.js 20.19+, npm, Python 3.10–3.12, uv, and a running Docker-compatible
runtime. Set up a fresh checkout exactly as documented:

```bash
npm ci
npm ci --prefix frontend
uv sync --project backend
cp .env.example .env
npm run dev
```

`npm run dev` runs PostgreSQL/Adminer in Compose and Uvicorn/Vite natively. Use Ctrl-C; do not
manually leave backing services running. Check container names against the current directory
prefix before stopping anything. The supervisor supports Docker Desktop, Colima, native Linux,
the Compose plugin, and standalone `docker-compose`.

Supported root vocabulary: `dev`, `check`, `fix`, `test`, `build`, `verify`, `db:migrate`,
`db:revision`, and `test:deploy`. Playwright and generation have dedicated commands documented
in the component guides.

## Backend

- Tables belong in `backend/app/tables.py`; use SQLModel `table=True` and UUID primary keys.
- API schemas belong in `backend/app/models.py`; keep create/update/public models distinct.
- Database operations belong in `backend/app/crud.py`, with keyword-only arguments and types.
- Routes belong in `backend/app/api/routes/`, use injected session/current user, declare response
  models/status codes, and are registered in `backend/app/api/main.py`.
- Settings and secrets belong in `backend/app/core/config.py`. Mirror every `.env` key in
  `.env.example` and never hardcode a secret.
- Schema changes require a new Alembic revision. Do not edit existing history. Use root `db:*`
  commands while the local database is running.
- `MIGRATE_ON_START` never disables exact-head checking. Treat a migration lock timeout or head
  mismatch as a failed startup.
- Define forward SQLModel relationships with quoted class names; do not enable postponed
  annotations for that purpose.

## Frontend

- Use the existing shadcn/ui primitives and Tailwind CSS utilities; keep reusable primitives under
  `frontend/src/components/ui`.
- Routes live in `frontend/src/routes`; protected pages stay under `_layout` and export `Route`.
- Use TanStack Query and the generated client for normal HTTP calls. Invalidate affected queries
  after mutations.
- Never edit `frontend/src/client` or `frontend/src/routeTree.gen.ts`; run
  `npm run generate-client`.
- Use npm only. Keep direct dependencies exact-pinned and update the npm lockfile deliberately.

## Verification

Use the smallest high-signal test set during development and finish with:

```bash
npm run verify
npm run test:deploy
```

Backend tests are hermetic Testcontainers tests. Playwright is a separate browser gate; use the
container command in `frontend/README.md` when native browsers are unavailable. For schema or
route work, also run `npm run generate-client` and ensure `npm run check:generated` stays clean.

The detailed maintenance workflow is in `.agents/skills/cen-template-maintenance/SKILL.md` and
`.docs/maintenance.md`.
