# Development

## Prerequisites

- Node.js 20.19 or newer with npm
- Python 3.10–3.12
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- A running Docker runtime with the Docker Compose plugin, such as Docker Desktop or Colima

Bootstrap a fresh checkout with exactly these four commands:

```bash
cp .env.example .env
npm ci
npm --prefix frontend ci
uv sync --project backend
```

The example values are suitable for local development. Replace every `changethis`
value before deploying.

## Native development loop

Start all development processes from the repository root:

```bash
npm run dev
```

The supervisor checks `.env`, required tools, installed dependencies, and all four
ports before it changes local state. It then:

1. starts PostgreSQL and Adminer in Docker Compose and waits for both;
2. applies pending Alembic migrations and idempotently creates the initial superuser;
3. starts reload-enabled Uvicorn and strict-port Vite as native processes; and
4. watches `backend/app` and atomically regenerates the OpenAPI client and route tree.

If a backend edit temporarily breaks imports, client generation reports the error and
retries until the source is valid again. Supervisor output interleaves child logs with
`[backend]`, `[frontend]`, `[client]`, `[compose]`, `[migrations]`, and `[seed]` prefixes.

Press Ctrl-C once to stop Uvicorn, Vite, the watcher, and the Compose services. Shutdown
does not remove `app-db-data`, so the existing developer database survives. Application
code no longer runs in Compose during development; Compose contains only `db` and
`adminer`.

## Ports and URLs

| `.env` key | Default | Service |
| --- | ---: | --- |
| `WEB_PORT` | 5173 | Web app: `http://localhost:5173` |
| `API_PORT` | 8000 | API: `http://localhost:8000` |
| `ADMINER_PORT` | 8080 | Adminer: `http://localhost:8080` |
| `DB_PORT` / `POSTGRES_PORT` | 5432 | PostgreSQL on localhost |

Swagger UI is at `http://localhost:8000/docs`; ReDoc is at
`http://localhost:8000/redoc`. `DB_PORT` and `POSTGRES_PORT` must match because the
native backend connects through the Compose-published database port.

## Tests

Run the branch-appropriate suite with:

```bash
npm run test
```

Backend tests provision a disposable PostgreSQL 12 container for each pytest session,
apply all Alembic migrations, and inject isolated settings and an isolated engine into
the application factory. They do not read or modify `.env` and do not depend on the
development Compose database. Browser tests remain separate:

```bash
npm run test:e2e
```

To use an existing PostgreSQL test database instead of Testcontainers, set
`TEST_DATABASE_URL`. Its database name must contain `test`; set
`TEST_DATABASE_ALLOW_UNSAFE_NAME=1` only when you intentionally accept the suite's
migration and data-deletion behavior.

## Troubleshooting

Port conflicts are reported before Compose starts. Either stop the named process or
container, or update all affected port values in `.env`, then rerun `npm run dev`.
Backing-service logs remain available through `docker compose logs db adminer`.
