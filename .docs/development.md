# Development

FastAPI and Vite run natively for hot reload. Docker Compose runs only PostgreSQL,
Adminer, Dex, and oauth2-proxy. The browser always enters through oauth2-proxy; do
not use the native Vite URL as an application entry point.

## First run

Install Node.js 20.19+, npm, uv, and a Docker-compatible runtime. Then run:

```bash
cp .env.example .env
npm ci
npm --prefix frontend ci
uv sync --project backend
npm run dev
```

On the first `npm run dev`, the runner replaces the three
`generate-on-first-dev-run` markers in `.env` with strong checkout-local values
and restricts the file permissions. It validates ports and the local database
target, starts the four Compose services, waits for PostgreSQL, Adminer, Dex, and
oauth2-proxy, applies Alembic migrations, and then starts native uvicorn and Vite.
There is no user seed because OAuth subjects are not stored in a user table.

All ports and the local Dex test credentials come from the root `.env`. With the
example ports, the browser entry is `http://localhost:4180`, Dex is
`http://localhost:5556/dex`, the loopback-only API is `http://127.0.0.1:8000`,
Vite is `http://localhost:5173`, and Adminer is `http://localhost:8080`.

Press Ctrl-C once for graceful native-process shutdown followed by `compose down`.
A second Ctrl-C accelerates cleanup. The PostgreSQL named volume is preserved.
The runner detects both `docker compose` and standalone `docker-compose` (including
Colima setups). It detects the daemon runtime before Compose starts and selects the
container-to-host path without overriding runtime-native DNS:

- Docker Desktop uses `host.docker.internal` with Docker Desktop's native mapping.
- Colima uses `host.lima.internal` with Colima/Lima's native mapping and no
  override for that hostname.
- Native Linux Docker uses `host.docker.internal` plus an explicit `host-gateway`
  mapping.

After Vite starts, the runner performs an HTTP probe from a container to the selected
host and stops with a runtime- and hostname-specific error if that path is broken.

## Authentication boundary

Local development uses the bundled Dex password account. oauth2-proxy owns the
browser session, validates nonce and PKCE S256, strips client identity headers,
and injects normalized identity plus a per-checkout upstream credential. FastAPI
accepts identity only when that credential is present and binds to loopback in the
native runner. Direct bearer tokens and forwarded headers are not authentication.

Dex is pinned to the v2.45.1 distroless multi-architecture image by digest. This was
the current stable upstream release reviewed on August 7, 2026; the tag documents the
release while the digest prevents an unreviewed image change.

Deployments continue to support an external OIDC provider through the standard
`OAUTH2_PROXY_CLIENT_ID`, `OAUTH2_PROXY_CLIENT_SECRET`, and
`OAUTH2_PROXY_OIDC_ISSUER_URL` environment values used by the deployment assets.
Use `OAUTH2_PROXY_COOKIE_SECURE=true` behind HTTPS and provide independent random
cookie and upstream secrets. Non-local backend startup rejects placeholder or
obviously weak values.

## Commands

```bash
npm run verify
npm run generate-client
npm run test:e2e
npm run test:e2e:container
npm run db:migrate
```

Client generation is offline and atomic: it constructs OpenAPI from the app
factory, generates into a staging directory, type-checks it, and publishes only a
complete client. `npm run verify` does not read `.env`; backend tests use a
disposable Testcontainers PostgreSQL database unless `TEST_DATABASE_URL` names an
explicit strict test database.
