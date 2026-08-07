# Backend-only CEN Template

This branch is a FastAPI/SQLModel/PostgreSQL API secured with `X-API-Key`. It has no frontend,
browser application, generated TypeScript client, or Playwright suite. Development runs Uvicorn
natively while Compose runs PostgreSQL and Adminer. Production is one backend image plus database.

## Quick start

Prerequisites: Node.js 20.19+ with npm, Python 3.10–3.12, uv, and Docker Desktop, Colima, or
native Linux Docker with either Compose command.

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

There is intentionally no `npm ci --prefix frontend`. Open the API at
`http://localhost:8000`, docs at `http://localhost:8000/docs`, health at
`http://localhost:8000/api/v1/utils/health-check/`, and Adminer at
`http://localhost:8080`. Protected routes require `X-API-Key` matching `.env`.

## Commands

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start PostgreSQL/Adminer and native reload-enabled Uvicorn |
| `npm run check` / `npm run fix` | Check or fix root JavaScript and Python |
| `npm run test` | Run supervisor, deploy mocks, and hermetic backend tests |
| `npm run build` | Build the production backend image |
| `npm run verify` | Run checks and tests; image build is separate |
| `npm run db:migrate` / `npm run db:revision -- -m "message"` | Manage Alembic |
| `npm run test:deploy` | Run Code Engine/OpenShift deployment mocks |

Frontend-specific commands (`typecheck`, `generate-client`, Playwright) do not exist because this
branch has no frontend. See [.docs/development.md](.docs/development.md),
[backend/README.md](backend/README.md), and [.docs/migration-guide.md](.docs/migration-guide.md).

Deployment: [Code Engine](.docs/ce-deployment.md), [OpenShift](.docs/oc-deployment.md).
