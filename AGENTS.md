# Working conventions

This is the backend-only, PostgreSQL, API-key branch. Do not add frontend, user/auth, ownership,
or bearer-token surfaces.

## Setup

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

`npm run dev` runs PostgreSQL/Adminer in Compose and Uvicorn natively. Supported root vocabulary:
`dev`, `check`, `fix`, `test`, `build`, `verify`, `db:migrate`, `db:revision`, and `test:deploy`.
Frontend install, generated-client, and Playwright commands intentionally do not exist. The
supervisor supports Docker Desktop, Rancher Desktop with
the dockerd/moby backend, native Linux Docker, and Podman with an available Compose provider.

## Backend rules

- SQLModel tables in `backend/app/tables.py`; API schemas in `models.py`; database work in
  `crud.py`; thin dependency-injected routes in `api/routes`.
- Preserve API-key auth and the unowned item shape. Do not revive deleted user fixtures/helpers.
- Mirror `.env` keys in `.env.example` and settings. Never hardcode secrets.
- Use new Alembic revisions and root `db:*` commands; never edit existing history.
- Exact-head checking remains mandatory when `MIGRATE_ON_START=false`.
- Backend tests must remain hermetic Testcontainers tests and must not read developer `.env`.

Finish with `npm run verify`, `npm run test:deploy`, and `npm run build` when image behavior is in
scope. Check container name prefixes before stopping services. See `.docs/development.md` and the
maintenance skill/docs for cross-branch work.
