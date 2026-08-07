# Backend development

The backend is FastAPI with SQLModel, PostgreSQL, Alembic, and local bearer-token
authentication. Install its locked environment from the repository root:

```bash
uv sync --project backend
```

The supported development entry point is `npm run dev`; PostgreSQL/Adminer run in Compose and
Uvicorn runs natively. See [the development guide](../.docs/development.md).

## Structure and conventions

- `app/tables.py`: SQLModel database tables
- `app/models.py`: request/response schemas
- `app/crud.py`: database operations
- `app/api/routes/`: dependency-injected route handlers
- `app/core/config.py`: settings loaded from the repository-root `.env`
- `app/alembic/`: migration environment and immutable revision history

Keep database work in `crud.py`, use keyword-only arguments and type hints, and keep routes thin.
Every `.env` key must exist in `.env.example` and in the settings model. Do not hardcode secrets.

## Migrations and startup

After changing a table, keep the development database running and use:

```bash
npm run db:revision -- -m "Describe the schema change"
npm run db:migrate
```

Never delete or squash shipped revisions. Backend startup owns migration execution: with
`MIGRATE_ON_START=true`, replicas serialize on a PostgreSQL advisory lock, upgrade, verify the
exact bundled head, and seed before readiness. With it disabled, exact-head verification still
runs. `MIGRATION_LOCK_TIMEOUT_SECONDS` bounds lock waiting. Any mismatch or migration failure
is a startup failure, not a warning.

## Tests

```bash
npm run test:backend
npm run verify
```

Tests are hermetic and use a disposable Testcontainers PostgreSQL instance. They do not require
the development Compose stack or read the repository `.env`. See the development guide before
using `TEST_DATABASE_URL`; unsafe database names are rejected by default.
