# Migrating an existing backend-only checkout

Development now uses a native Uvicorn process supervised by root npm. Compose runs only
PostgreSQL and Adminer. The production backend Dockerfile and image behavior are unchanged.

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

Node/npm, Python, and uv are new host prerequisites. Update `.env` with native ports,
`MIGRATE_ON_START=true`, and `MIGRATION_LOCK_TIMEOUT_SECONDS=60`. Startup refuses occupied ports,
unsafe remote databases, and schemas not exactly at bundled Alembic heads. Backend tests now use a
disposable Testcontainers database.

## Adopting an old OpenShift deployment

Back up PostgreSQL and run `./scripts/oc-deploy.sh --adopt-legacy-resources` against the existing
project. The deployer fingerprints and prints the exact legacy set, refuses ambiguity or partial
labels, and changes ownership only after `adopt <PROJECT_NAME>/<APP_NAME>`. PostgreSQL credential
drift has a separate typed destructive reset; adoption itself never deletes data.

Breaking changes: the old Compose application loop is removed; root npm commands are canonical;
npm is the only JavaScript tool; application startup owns migrations; the dead user/owner surface
has been removed. No frontend command should be added for this branch.

Blank OpenShift branch filters now resolve to `backend-only` and must exist remotely before the
BuildConfig is created. Legacy resources require the verified adoption flow above.

Rollback tag: `pre-modernization/backend-only`.

```bash
git switch --detach pre-modernization/backend-only
```

Create a recovery branch and back up PostgreSQL before rollback if migrations have run.
