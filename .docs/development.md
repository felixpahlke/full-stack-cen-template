# Development

## Prerequisites and first run

- Node.js 20.19 or newer
- [pnpm](https://pnpm.io/installation) (the repository pins the supported version)
- Python 3.10–3.12
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- Docker Desktop, Rancher Desktop with the dockerd/moby backend, native Linux Docker, or Podman
- Docker: `docker compose` or standalone `docker-compose`
- Podman: `podman compose` with `podman-compose` or standalone `docker-compose` as its provider,
  or the `podman-compose` command; start `podman machine` first where required

From a fresh checkout, run in this order:

```bash
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

Run `pnpm install` only from the repository root. It installs the root command facade, Biome, and
the frontend workspace from the frozen lockfile in CI. The backend environment is
`backend/.venv`; activate it only when an editor or an ad-hoc command requires activation.

## What development starts

`pnpm run dev` validates `.env`, tools, dependencies, and ports before changing state. It:

1. starts PostgreSQL 12 and Adminer in Compose;
2. starts native reload-enabled Uvicorn and Vite;
3. lets backend startup serialize migration/seeding through a PostgreSQL advisory lock; and
4. watches backend source and atomically regenerates the OpenAPI client and route tree.

Application code does not run in Compose. Repository `.env` values override inherited shell
values. A non-local `POSTGRES_SERVER` is refused unless `DEV_ALLOW_REMOTE_DB=1` is set
deliberately.

On the first Ctrl-C, children receive SIGINT and get up to five seconds. Remaining children
are killed, then Compose is stopped with bounded timeouts. The worst case is about 12 seconds.
A second Ctrl-C forces immediate child termination and a short Compose teardown. The named
database volume is not removed.

## Ports, URLs, and required environment

| Key | Default | Meaning |
| --- | ---: | --- |
| `WEB_PORT` | 5173 | Web app |
| `API_PORT` | 8000 | FastAPI and `/docs` |
| `ADMINER_PORT` | 8080 | Adminer |
| `DB_PORT` | 5432 | Host-side PostgreSQL port |
| `POSTGRES_PORT` | 5432 | Backend database port; must match `DB_PORT` locally |

Required non-empty settings are `CEN_FLAVOR`, `ENVIRONMENT`, `PROJECT_NAME`, `SECRET_KEY`,
`FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD`, `SIGNUP_ACCESS_PASSWORD`,
`BACKEND_CORS_ORIGINS`, and the five `POSTGRES_*` settings. `VITE_TELEMETRY_ENABLED` controls
flavor telemetry. Replace all `changethis` values before deployment.

## Migrate on start

`MIGRATE_ON_START=true` makes every backend process acquire advisory lock `7461001`, upgrade
to the Alembic heads bundled in this checkout, verify that the database is at exactly those
heads, and seed the initial user before serving. `MIGRATION_LOCK_TIMEOUT_SECONDS` limits how
long a replica waits for another migrator; the default is 60 seconds.

With `MIGRATE_ON_START=false`, no upgrade runs, but exact-head verification still does. A
timeout, broken migration, unreachable database, or extra/missing database revision aborts
startup. Readiness never becomes healthy; fix the schema or configuration instead of bypassing
the check.

Use the root migration commands:

```bash
pnpm run db:revision -- -m "Describe the schema change"
pnpm run db:migrate
```

Commit generated revisions. Never rewrite existing revision history.

## Testing and generation

```bash
pnpm run check
pnpm run test
pnpm run build
pnpm run verify
pnpm run test:deploy
```

Backend pytest uses Testcontainers to create a disposable PostgreSQL 12 database, applies all
migrations, and injects isolated settings. It does not read `.env` or touch the development
database. `TEST_DATABASE_URL` may replace Testcontainers only when the database name is clearly
test-only (`test`, `test_*`, `test-*`, `*_test`, or `*-test`).

Generated code is checked by `pnpm run check:generated`. Use `pnpm run generate-client` after an
API surface change; it derives OpenAPI without a running server and updates
`frontend/src/client` and `frontend/src/routeTree.gen.ts` atomically. Never edit either output.

Playwright is intentionally separate from `verify`. Start `pnpm run dev`, then follow the native
or containerized command in `frontend/README.md`. A local macOS sandbox may block native browser
launch even when the application is healthy.

On Podman, give the machine more memory than the 2 GiB default before running the containerized
Playwright suite: several parallel Chromium workers alongside PostgreSQL can exhaust it, and the
kernel then OOM-kills the database mid-run. Either `podman machine set --memory 8192` (stop and
restart the machine afterwards) or run the suite with `-- --workers=1`.

## Troubleshooting

- **Occupied port:** the preflight names every occupied port before Compose starts. Stop the
  process/container or change the paired values in `.env`.
- **Container command mismatch:** the supervisor prefers a working Docker runtime, then Podman,
  and selects that runtime's Compose form. This branch does not need host-to-container application
  routing.
- **Missing uv environment:** rerun `uv sync --project backend`; do not create a root venv.
- **Stale generated client:** run `pnpm run generate-client`, then `pnpm run check:generated`.
- **Backing-service logs:** use the Compose command reported by the supervisor with
  `logs db adminer`.
- **Stale services after interruption:** run the detected Compose command with `down`, then
  confirm no containers with this checkout's directory prefix remain.
