# Full Stack CEN Template — local authentication with Carbon

This branch provides a FastAPI/PostgreSQL backend, a React 19 frontend using IBM Carbon,
and built-in email/password authentication. Development runs the application processes
natively and uses Docker Compose only for PostgreSQL and Adminer. Production remains a
separate backend image and nginx frontend image.

## Quick start

Prerequisites: Node.js 20.19 or newer with npm, Python 3.10–3.12, uv, and a running
Docker-compatible runtime. Docker Desktop, Colima, native Linux Docker, the Compose plugin,
and standalone `docker-compose` are supported.

Run this exact sequence from a fresh checkout:

```bash
npm ci
npm ci --prefix frontend
uv sync --project backend
cp .env.example .env
npm run dev
```

Open the web app at `http://localhost:5173`, the API at `http://localhost:8000`, API docs
at `http://localhost:8000/docs`, and Adminer at `http://localhost:8080`. Log in with
`FIRST_SUPERUSER` and `FIRST_SUPERUSER_PASSWORD` from `.env`.

`npm run dev` starts PostgreSQL and Adminer in Compose, then runs reload-enabled Uvicorn
and Vite as native processes. It migrates the database and seeds the initial superuser
during backend startup. A backend source change also checks and regenerates the OpenAPI
client and route tree. Press Ctrl-C once for graceful shutdown; the supervisor forcibly
stops remaining children and Compose within about 12 seconds in the worst case. A second
Ctrl-C escalates immediately. The PostgreSQL volume is preserved.

## Root commands

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start backing services plus native backend/frontend development processes |
| `npm run check` | Check generated files, types, JavaScript/CSS, and Python |
| `npm run fix` | Apply supported Biome and Ruff fixes |
| `npm run test` | Run supervisor, deployment-mock, and hermetic backend tests |
| `npm run build` | Build the production frontend bundle |
| `npm run verify` | Run `check`, `test`, and `build` |
| `npm run db:migrate` | Upgrade the configured database to the bundled Alembic head |
| `npm run db:revision -- -m "message"` | Generate a migration after model changes |
| `npm run test:deploy` | Run Code Engine and OpenShift deployment mocks |
| `npm run test:e2e` | Run Playwright; see the container pattern in the frontend guide |
| `npm run generate-client` | Regenerate OpenAPI, the TypeScript client, and route tree |

## Documentation

- [Development, ports, environment, testing, and troubleshooting](.docs/development.md)
- [Backend development and migrations](backend/README.md)
- [Frontend development, generation, and Playwright](frontend/README.md)
- [Migration guide for existing consumers](.docs/migration-guide.md)
- [Code Engine deployment](.docs/ce-deployment.md)
- [OpenShift deployment](.docs/oc-deployment.md)
- [Release notes](.docs/release-notes.md) and [changelog](CHANGELOG.md)

This template is based on
[full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template).
