# Stateless backend development

The backend uses FastAPI and Pydantic with API-key authentication. It has no SQLModel tables,
database engine, Alembic tree, persistence dependencies, user accounts, or bearer tokens.

- `app/models.py`: Pydantic schemas
- `app/api/routes/`: protected example and public health routes
- `app/api/main.py`: router registration
- `app/core/config.py`: root `.env` settings
- `app/tests/` and `tests/`: Docker-free tests

Install with `uv sync --project backend`, run with root `npm run dev`, and verify with
`npm run verify`. Do not add database settings or migration commands unless intentionally moving
to a different branch/product shape.
