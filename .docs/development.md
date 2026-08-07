# Stateless FastAPI development

Development is entirely native for this flavor. There is no frontend, database, Compose stack, or
other backing service.

## Prerequisites

- Python 3.10–3.12
- Node.js 20.19 or newer with npm
- [uv](https://docs.astral.sh/uv/getting-started/installation/)

Install the locked dependencies from the repository root:

```bash
npm ci
uv sync --project backend
```

## Environment

Create a local environment file:

```bash
cp .env.example .env
```

`npm run dev` requires non-empty `PROJECT_NAME`, `API_KEY`, and `API_PORT` values in that file.
Application settings load `.env` from the repository root regardless of the shell's working
directory. Tests and quality checks inject isolated settings and therefore work without `.env`.

## Development server

```bash
npm run dev
```

The supervisor checks that uv and the backend environment exist, confirms `API_PORT` is free, and
starts native Uvicorn with reload. No Docker command is run. The default URLs are:

- API: `http://localhost:8000`
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- Health check: `http://localhost:8000/api/v1/utils/health-check/`

Press `Ctrl-C` once for a graceful shutdown. A second signal forces any remaining process to stop.

## Checks and tests

Run the complete local gate:

```bash
npm run verify
```

The gate checks `scripts/*.mjs` with Biome, checks and formats all backend Python with Ruff, runs
the Node supervisor tests, and runs plain pytest. It neither reads `.env` nor requires Docker.

Use `npm run fix` to apply supported formatting and safe lint fixes.
