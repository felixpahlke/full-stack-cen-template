# Development

## Prerequisites and first run

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

Node.js 20.19+, npm, Python 3.10–3.12, uv, and a running Docker-compatible runtime are required.
The supervisor supports Docker Desktop, Colima, native Linux Docker, `docker compose`, and
standalone `docker-compose`. There is no frontend install step.

## Runtime and ports

`npm run dev` validates `.env`, tools, the uv environment, Docker, and ports; starts PostgreSQL 12
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
npm run db:revision -- -m "Describe the schema change"
npm run db:migrate
npm run verify
npm run test:deploy
npm run build
```

Backend tests provision a disposable PostgreSQL 12 Testcontainers database, apply migrations,
and ignore `.env` and the development database. No Playwright test exists because there is no UI.

## Troubleshooting

Occupied ports are reported before startup. Stop the process/container or update paired `.env`
ports. If `backend/.venv` is missing, rerun `uv sync --project backend`. Use the detected Compose
command for `logs db adminer`. On Colima, verify the active Docker context. After interruption,
run Compose `down` and check that no container with this checkout's directory prefix remains.
