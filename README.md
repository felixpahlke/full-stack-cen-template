# Stateless FastAPI Template

This `backend-only-no-db` flavor is a small FastAPI service with no frontend and no database. It
exposes a public health check and an API-key-protected example endpoint.

## Requirements

- Python 3.10–3.12
- Node.js 20.19 or newer with npm
- [uv](https://docs.astral.sh/uv/)

Docker is not required for development, checks, or tests.

## Start development

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

The development supervisor validates the environment and API port, then starts Uvicorn with
reload at `http://localhost:8000`. Stop it with `Ctrl-C`.

- Health check: `GET http://localhost:8000/api/v1/utils/health-check/`
- Protected example: `GET http://localhost:8000/api/v1/example/hello` with `X-API-Key`
- Interactive API docs: `http://localhost:8000/docs`

![FastAPI interactive documentation](.docs/img/docs.png)

## Commands

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start the native Uvicorn reload server |
| `npm run check` | Check root JavaScript with Biome and all backend Python with Ruff |
| `npm run fix` | Apply Biome and Ruff fixes and formatting |
| `npm test` | Run supervisor unit tests and the plain pytest suites |
| `npm run verify` | Run all checks and tests |

See [.docs/development.md](./.docs/development.md) for details and
[backend/README.md](./backend/README.md) for the backend layout.

## Deployment

The production backend image remains available at `backend/Dockerfile`. Deployment guidance is in
[the OpenShift guide](./.docs/oc-deployment.md) and
[the Code Engine guide](./.docs/ce-deployment.md).

This template is based on
[full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template).
