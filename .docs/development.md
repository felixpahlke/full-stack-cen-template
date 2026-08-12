# Development

## Prerequisites and first run

- Node.js 20.19 or newer with Corepack and pnpm
- Python 3.10–3.12
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- Docker Desktop, Rancher Desktop with the dockerd/moby backend, native Linux Docker, or Podman
- Docker: `docker compose` or standalone `docker-compose`
- Podman: `podman compose` with `podman-compose` or standalone `docker-compose` as its provider,
  or the `podman-compose` command; start `podman machine` first where required

From a fresh checkout, run in this order:

```bash
corepack enable pnpm
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

There is no frontend install step.

## Runtime and ports

`pnpm run dev` validates `.env`, tools, the uv environment, Docker, and ports; starts PostgreSQL 12
and Adminer in Compose; and runs reload-enabled Uvicorn natively.

| Key | Default | Meaning |
| --- | ---: | --- |
| `API_PORT` | 8000 | API and `/docs` |
| `ADMINER_PORT` | 8080 | Adminer |
| `DB_PORT` / `POSTGRES_PORT` | 5432 | Host/database port; must match locally |

Required keys are `CEN_FLAVOR`, `ENVIRONMENT`, `PROJECT_NAME`, `BACKEND_CORS_ORIGINS`,
`API_KEY`, the five `POSTGRES_*` values, all three ports, and `TELEMETRY_ENABLED`. Replace
example credentials before deployment. A remote database is refused unless
`DEV_ALLOW_REMOTE_DB=1` is set intentionally.

One Ctrl-C gives Uvicorn up to five seconds, kills any survivor, then performs bounded Compose
shutdown. Worst case is about 12 seconds; a second Ctrl-C escalates immediately. The database
volume survives.

## Database startup and tests

`MIGRATE_ON_START=true` serializes replicas with PostgreSQL advisory lock `7461001`, upgrades to
the bundled Alembic heads, verifies exact head equality, and completes startup before readiness.
`MIGRATION_LOCK_TIMEOUT_SECONDS` defaults to 60. Setting migration false skips the upgrade but
not exact-head verification. A timeout, unreachable database, bad migration, or mismatch prevents
readiness.

```bash
pnpm run db:revision -- -m "Describe the schema change"
pnpm run db:migrate
pnpm run verify
pnpm run test:deploy
pnpm run build
```

Backend tests provision a disposable PostgreSQL 12 Testcontainers database, apply migrations,
and ignore `.env` and the development database. No Playwright test exists because there is no UI.

## Troubleshooting

- **Occupied port:** the preflight names every occupied port before Compose starts. Stop the
  process/container or change the paired values in `.env`.
- **Container command mismatch:** the supervisor prefers a working Docker runtime, then Podman,
  and selects that runtime's Compose form. This branch does not need host-to-container application
  routing.
- **Missing uv environment:** rerun `uv sync --project backend`; do not create a root venv.
- **Backing-service logs:** use the Compose command reported by the supervisor with
  `logs db adminer`.
- **Stale services after interruption:** run the detected Compose command with `down`, then
  confirm no containers with this checkout's directory prefix remain.
