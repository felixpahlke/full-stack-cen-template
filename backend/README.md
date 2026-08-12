# Backend development

The FastAPI/SQLModel/PostgreSQL backend trusts identity only across the oauth2-proxy boundary.
Install with `uv sync --project backend` and run the full stack with `pnpm run dev`.

The proxy supplies a normalized opaque subject plus user fields and authenticates to the backend
with the checkout-specific `OAUTH2_PROXY_UPSTREAM_PASSWORD` over Basic Auth. The backend binds to
loopback in local development and rejects direct bearer auth, spoofed forwarded headers, missing
identity, and an incorrect seam credential. Preserve that boundary when adding routes.

Database structure lives in `app/tables.py`; API schemas in `app/models.py`; database work in
`app/crud.py`; routes in `app/api/routes`; settings in `app/core/config.py`. Keep route handlers
thin and never hardcode secrets.

Use `create_app`, `get_settings`, and `get_engine` for injected code. The historical module-level
`app`, `settings`, and `engine` imports remain lazy compatibility exports. The production image
serves the factory directly with Uvicorn; never introduce a wrapper application that delegates
only ASGI calls because it breaks FastAPI introspection and extension registration.

## Migrations and tests

```bash
pnpm run db:revision -- -m "Describe the schema change"
pnpm run db:migrate
pnpm run test:backend
```

Do not rewrite existing revisions. Migrate-on-start serializes replicas and verifies exact bundled
heads before readiness even when upgrades are disabled. Backend tests are hermetic Testcontainers
tests and do not use `.env` or the development database.

`pnpm run check` includes strict mypy, Ruff linting, and Ruff formatting checks for the backend.
