# Backend development

This FastAPI backend uses SQLModel, PostgreSQL, Alembic, and `X-API-Key` authentication. It has no
user table, ownership field, bearer authentication, frontend, or generated browser client.

- `app/tables.py`: item tables
- `app/models.py`: request/response schemas
- `app/crud.py`: unowned CRUD
- `app/api/routes/`: API-key-protected routes and public health
- `app/core/config.py`: root `.env` settings
- `app/alembic/`: migration history

Install with `uv sync --project backend`; run with root `npm run dev`. Keep database work in CRUD,
routes thin, and settings mirrored in `.env.example`.

Use root `db:revision` and `db:migrate`; never rewrite shipped revisions. Startup always verifies
exact bundled heads and optionally migrates under an advisory lock. Tests use a disposable
Testcontainers PostgreSQL instance:

```bash
npm run verify
```
