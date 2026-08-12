# Migrating an existing backend-only checkout

## Move an older checkout to pnpm

After updating an npm-based checkout, remove the old root install and lockfile, then install once:

```bash
rm -rf node_modules
rm -f package-lock.json
corepack enable pnpm
pnpm install
```

This flavor has no frontend package and therefore no workspace manifest or second install.

Development now uses a native Uvicorn process supervised by root pnpm. Compose runs only
PostgreSQL and Adminer. The backend image now starts Uvicorn with the
`app.main:create_app` factory.

```bash
corepack enable pnpm
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

Node/pnpm, Python, and uv are new host prerequisites. Update `.env` with native ports,
`MIGRATE_ON_START=true`, and `MIGRATION_LOCK_TIMEOUT_SECONDS=60`. Startup refuses occupied ports,
unsafe remote databases, and schemas not exactly at bundled Alembic heads. Backend tests now use a
disposable Testcontainers database.

## Backend extension API compatibility

New extension code should prefer `create_app`, `get_settings`, and `get_engine`. Existing
`from app.main import app`, `from app.core.config import settings`, and
`from app.core.db import engine` imports remain supported as lazy factory-backed exports. The
exported `app` is the actual configured `FastAPI` instance, so router inclusion, middleware,
exception handlers, route inspection, and OpenAPI customization operate on the served application.
Importing `app.main` without requesting `app` still constructs no settings. Both `init_db(session)`
and `init_db(session, settings)` remain accepted.

## Adopting an old OpenShift deployment

Back up PostgreSQL and run `./scripts/oc-deploy.sh --adopt-legacy-resources` against the existing
project. The deployer fingerprints and prints the exact legacy set, refuses ambiguity or partial
labels, and changes ownership only after `adopt <PROJECT_NAME>/<APP_NAME>`. PostgreSQL credential
drift has a separate typed destructive reset; adoption itself never deletes data.

Breaking changes: the old Compose application loop is removed; root pnpm commands are canonical;
pnpm is the only JavaScript tool; application startup owns migrations; the dead user/owner surface
has been removed. No frontend command should be added for this branch.

Blank OpenShift branch filters now resolve to `backend-only` and must exist remotely before the
BuildConfig is created. Legacy resources require the verified adoption flow above.

Rollback tag: `pre-modernization/backend-only`.

```bash
git switch --detach pre-modernization/backend-only
```

Create a recovery branch and back up PostgreSQL before rollback if migrations have run.
