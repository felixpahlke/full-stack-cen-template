# Stateless development

## First run

```bash
corepack enable pnpm
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

Node.js 20.19+, pnpm, Python 3.10–3.12, and uv are required. Docker and Compose are not required
for development, `check`, `test`, `verify`, or `test:deploy`. There is no frontend dependency
installation.

`pnpm run dev` validates `.env`, uv, `backend/.venv`, and `API_PORT`, then starts native Uvicorn
with reload. It starts no backing service. Required non-empty keys are `CEN_FLAVOR`,
`ENVIRONMENT`, `PROJECT_NAME`, `BACKEND_CORS_ORIGINS`, `API_KEY`, `API_PORT`, and
`TELEMETRY_ENABLED`.

| Key | Default | URL |
| --- | ---: | --- |
| `API_PORT` | 8000 | API, `/docs`, and `/api/v1/utils/health-check/` |

One Ctrl-C gives Uvicorn up to five seconds, then kills any survivor. A second Ctrl-C forces
immediate termination. There is no Compose teardown and no database volume.

## Quality and troubleshooting

```bash
DOCKER_HOST=unix:///nonexistent pnpm run verify
pnpm run test:deploy
```

The explicit invalid `DOCKER_HOST` is an optional proof that tests are Docker-free, not a setup
requirement. `pnpm run build` is deliberately outside `verify` because image building needs Docker
or Podman. No migration or Playwright instructions exist for this branch.

If the API port is occupied, stop the reported process or change `API_PORT`. If the uv environment
is missing, rerun `uv sync --project backend`. If settings appear stale, verify commands are run
from the checkout root and refresh `.env` from `.env.example`.
