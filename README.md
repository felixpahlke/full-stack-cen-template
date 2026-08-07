# Stateless backend-only CEN Template

This branch is a FastAPI API secured with `X-API-Key`. It has no frontend, database, migrations,
Compose file, generated client, or Playwright suite. Development and tests are Docker-free;
Docker is needed only to build the production image or deploy it.

## Quick start

Prerequisites: Node.js 20.19+ with npm, Python 3.10–3.12, and uv.

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

Open the API at `http://localhost:8000`, docs at `http://localhost:8000/docs`, public health at
`http://localhost:8000/api/v1/utils/health-check/`, and the protected example endpoint at
`http://localhost:8000/api/v1/example/hello` with `X-API-Key` from `.env`.

## Commands

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start native reload-enabled Uvicorn; no containers |
| `npm run check` / `npm run fix` | Check or fix JavaScript and Python |
| `npm run test` | Run supervisor, deploy mocks, and Docker-free pytest |
| `npm run build` | Build the production backend image; this command needs Docker |
| `npm run verify` | Run all Docker-free checks and tests |
| `npm run test:deploy` | Run mock-only Code Engine/OpenShift tests |

There is no frontend install, browser test, code generation, `db:migrate`, or `db:revision`
command because the branch has neither frontend nor database. See
[development](.docs/development.md), [backend](backend/README.md), and the
[consumer migration guide](.docs/migration-guide.md).
