# Full Stack CEN Template — OAuth proxy with custom UI

This branch provides FastAPI/PostgreSQL, a React 19 frontend using shadcn/ui, and an
oauth2-proxy authentication boundary. Development uses local Dex and oauth2-proxy containers,
native Uvicorn/Vite, and Compose-hosted PostgreSQL/Adminer. Production keeps separate backend and
nginx frontend images plus the proxy.

## Quick start

Prerequisites: Node.js 20.19+ with npm, Python 3.10–3.12, uv, and Docker Desktop, Colima, or
native Linux Docker with either Compose command.

```bash
npm ci
npm ci --prefix frontend
uv sync --project backend
cp .env.example .env
npm run dev
```

Enter through the proxy at `http://localhost:4180`, never the direct Vite port. The local Dex
login uses `DEX_TEST_USER_EMAIL` and `DEX_TEST_USER_PASSWORD` from `.env`. The API is bound to
`127.0.0.1:8000`; Vite is at `http://localhost:5173`, Dex at
`http://localhost:5556/dex`, and Adminer at `http://localhost:8080`.

`npm run dev` generates strong per-checkout local proxy secrets when marker values are present,
starts PostgreSQL/Adminer/Dex/oauth2-proxy in Compose, and starts Uvicorn/Vite natively. Ctrl-C
stops native children and removes development containers; worst case is about 12 seconds. A
second Ctrl-C escalates immediately. Database data is preserved.

## Root commands

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start backing/auth services and native backend/frontend processes |
| `npm run check` / `npm run fix` | Check or fix generated, frontend, and backend sources |
| `npm run test` | Run supervisor, deployment-mock, and hermetic backend tests |
| `npm run build` | Build the production frontend bundle |
| `npm run verify` | Run `check`, `test`, and `build` |
| `npm run db:migrate` / `npm run db:revision -- -m "message"` | Manage Alembic revisions |
| `npm run test:deploy` | Run Code Engine/OpenShift mocks and OAuth deployment assertions |
| `npm run test:e2e:container` | Run the real Dex/proxy Playwright flow in a matching container |
| `npm run generate-client` | Regenerate OpenAPI, client, and routes |

## OAuth behavior

Browser sign-in starts at `/oauth2/sign_in`; the proxy establishes the session and passes a
normalized identity to the backend through a private Basic credential. Browser-supplied identity
headers or bearer tokens are not trusted. `/oauth2/sign_out` ends the proxy session, but it does
**not** end the upstream identity provider's SSO session. A subsequent login can therefore be
silent until the IdP session itself expires or is ended at the IdP.

## Documentation

- [Development and OAuth details](.docs/development.md)
- [Backend identity boundary and migrations](backend/README.md)
- [Frontend, generated code, and Playwright](frontend/README.md)
- [Migration guide](.docs/migration-guide.md)
- [Code Engine](.docs/ce-deployment.md) and [OpenShift](.docs/oc-deployment.md)
- [Release notes](.docs/release-notes.md) and [changelog](CHANGELOG.md)
