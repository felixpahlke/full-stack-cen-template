# Backend-only Client Engineering Template

This flavor provides a FastAPI and PostgreSQL API with unowned item CRUD protected by
an `X-API-Key` header. It has no frontend. The public health endpoint and FastAPI's
generated Swagger/ReDoc pages are the browser-facing surface.

## Technology

- FastAPI, SQLModel, PostgreSQL, and Alembic
- API-key authentication for item routes
- Docker Compose for PostgreSQL and Adminer during development
- Native reload-enabled Uvicorn via the root npm development supervisor
- OpenShift and Code Engine deployment scripts

This repository is based on
[full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template)
and is one flavor of [create-cen-app](https://github.com/felixpahlke/create-cen-app).

## Quick start

Prerequisites are Node.js 20.19+, npm, Python 3.10–3.12, uv, and a running Docker
runtime with either `docker compose` or standalone `docker-compose`.

```bash
cp .env.example .env
npm ci
uv sync --project backend
npm run dev
```

The supervisor starts PostgreSQL 12 and Adminer in Compose, applies migrations, and
runs Uvicorn natively with reload. It does not seed users because this flavor has no
user table.

- API: `http://localhost:8000`
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- Adminer: `http://localhost:8080`

Use the configured API key for item CRUD:

```bash
curl -H 'X-API-Key: changethis12345678' http://localhost:8000/api/v1/items/
```

The health check is public:

```bash
curl http://localhost:8000/api/v1/utils/health-check/
```

See [development.md](./.docs/development.md) for the environment contract, shutdown
behavior, tests, database commands, and troubleshooting. Backend-specific conventions
are in [backend/README.md](./backend/README.md).

## Quality

```bash
npm run verify
```

This runs script checks, Ruff lint and format checks across the backend, and hermetic
backend tests. Tests start their own disposable PostgreSQL container and require no
`.env` or running development Compose stack.

## Deployment

- [OpenShift deployment](./.docs/oc-deployment.md)
- [Code Engine deployment](./.docs/ce-deployment.md)
- [Deployment script reference](./scripts/README.md)
