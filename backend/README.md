# Backend development

The backend is FastAPI with SQLModel, PostgreSQL, Alembic, and API-key authentication.
Install its Python environment from the repository root:

```bash
uv sync --project backend
```

Start the complete development loop with `npm run dev`; see
[development.md](../.docs/development.md). PostgreSQL and Adminer run in Compose while
Uvicorn runs natively with reload.

## Structure

- `app/tables.py`: SQLModel database tables
- `app/models.py`: request and response schemas
- `app/crud.py`: database operations
- `app/api/routes/`: HTTP route handlers
- `app/core/config.py`: environment-backed settings
- `app/alembic/`: migration environment and revisions

The item API is unowned. Its routes require `X-API-Key`; the health endpoint is public.

## Commands

Run all supported checks and tests from the repository root:

```bash
npm run verify
```

Apply migrations or generate a revision with:

```bash
npm run db:migrate
npm run db:revision -- -m "Describe the schema change"
```

Schema changes must use Alembic. Do not edit or replace existing migration history.

Backend tests use Testcontainers and a disposable PostgreSQL 12 database. An explicitly
provided `TEST_DATABASE_URL` is accepted only when its database name is clearly test-only;
see [development.md](../.docs/development.md) for the guard rules.
