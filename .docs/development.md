# Development

## Prerequisites

- Node.js 20.19 or newer with npm
- Python 3.10–3.12
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- A running Docker runtime with either the `docker compose` plugin or standalone
  `docker-compose`, such as Docker Desktop or Colima

Bootstrap a fresh checkout with:

```bash
cp .env.example .env
npm ci
uv sync --project backend
```

The example values are suitable for local development. Replace every `changethis`
value before deploying.

## Native development loop

Start development from the repository root:

```bash
npm run dev
```

The supervisor checks `.env`, required tools, installed dependencies, and the database,
Adminer, and API ports before changing local state. It then starts PostgreSQL and Adminer
in Compose, applies pending Alembic migrations, and runs reload-enabled Uvicorn natively.
There is no frontend or seed step on this flavor.

Values from the repository `.env` override inherited shell exports. The supervisor
refuses to migrate a non-local `POSTGRES_SERVER`; set `DEV_ALLOW_REMOTE_DB=1` only when
that remote target is intentional.

Press Ctrl-C once to forward SIGINT to Uvicorn. After at most five seconds, remaining
children receive SIGKILL; Compose then runs `down` with a one-second service timeout and
a five-second supervisor cap. Press Ctrl-C a second time to escalate immediately.
Shutdown preserves the existing `app-db-data` volume.

## Ports and URLs

| `.env` key | Default | Service |
| --- | ---: | --- |
| `API_PORT` | 8000 | API: `http://localhost:8000` |
| `ADMINER_PORT` | 8080 | Adminer: `http://localhost:8080` |
| `DB_PORT` / `POSTGRES_PORT` | 5432 | PostgreSQL on localhost |

Swagger UI is at `http://localhost:8000/docs`; ReDoc is at
`http://localhost:8000/redoc`. `DB_PORT` and `POSTGRES_PORT` must match because the
native backend connects through the Compose-published database port.

Secured item routes require the configured key:

```bash
curl -H 'X-API-Key: changethis12345678' http://localhost:8000/api/v1/items/
```

The health check is public at `http://localhost:8000/api/v1/utils/health-check/`.

## Quality and tests

```bash
npm run verify
```

Backend tests provision a disposable PostgreSQL 12 container for each pytest session,
apply the existing Alembic migration, and inject isolated settings and an isolated
engine. They do not read or modify `.env` and do not depend on the development Compose
database.

To use an existing PostgreSQL test database, set `TEST_DATABASE_URL`. Its database name
must be exactly `test`, start with `test_` or `test-`, or end with `_test` or `-test`.
Set `TEST_DATABASE_ALLOW_UNSAFE_NAME=1` only when you intentionally accept the suite's
migration and data-deletion behavior.

## Database commands

```bash
npm run db:migrate
npm run db:revision -- -m "Describe the schema change"
```

## Troubleshooting

Port conflicts are reported before Compose starts. Stop the named process or container,
or update all affected port values in `.env`. Backing-service logs remain available via
`docker compose logs db adminer` or `docker-compose logs db adminer`, matching the command
detected by the supervisor.
