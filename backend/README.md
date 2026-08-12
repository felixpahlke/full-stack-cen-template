# Backend development

This FastAPI backend uses SQLModel, PostgreSQL, Alembic, and `X-API-Key` authentication. It has no
user table, ownership field, bearer authentication, frontend, or generated browser client.

- `app/tables.py`: item tables
- `app/models.py`: request/response schemas
- `app/crud.py`: unowned CRUD
- `app/api/routes/`: API-key-protected routes and public health
- `app/core/config.py`: root `.env` settings
- `app/alembic/`: migration history

Install with `uv sync --project backend`; run with root `pnpm run dev`. Keep database work in CRUD,
routes thin, and settings mirrored in `.env.example`.

Use `create_app`, `get_settings`, and `get_engine` for injected code. Historical module-level
`app`, `settings`, and `engine` imports remain lazy compatibility exports. The production image
serves the factory directly with Uvicorn; never wrap it in an ASGI-only forwarding shell.

Use root `db:revision` and `db:migrate`; never rewrite shipped revisions. Startup always verifies
exact bundled heads and optionally migrates under an advisory lock. Tests use a disposable
Testcontainers PostgreSQL instance:

```bash
pnpm run verify
```

The verification gate includes strict mypy, Ruff linting, and Ruff formatting checks.
