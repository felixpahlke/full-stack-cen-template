# Development

## Prerequisites and first run

- Node.js 20.19+ with Corepack and pnpm
- Python 3.10–3.12 and uv
- Docker Desktop, Rancher Desktop with the dockerd/moby backend, native Linux Docker, or Podman
- Docker: `docker compose` or standalone `docker-compose`
- Podman: `podman compose` with `podman-compose` or standalone `docker-compose` as its provider,
  or the `podman-compose` command; start `podman machine` first where required

```bash
corepack enable pnpm
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

The supervisor detects Docker Desktop, Rancher Desktop, native Linux Docker, or Podman and selects
the correct container-to-host Vite address. It refuses missing tools, dependencies, environment
values, unsafe remote databases, or occupied ports before starting services.

## Topology, ports, and environment

Compose starts PostgreSQL, Adminer, oauth2-proxy, and—by default—Dex. Uvicorn and Vite run
natively with reload/HMR. The backend is loopback-only; browsers must use the proxy.

| Key | Default | URL/service |
| --- | ---: | --- |
| `OAUTH2_PROXY_PORT` | 4180 | Browser entry: `http://localhost:4180` |
| `WEB_PORT` | 5173 | Vite upstream; not the authenticated entry |
| `API_PORT` | 8000 | Loopback backend |
| `DEX_PORT` | 5556 | Local issuer under `/dex` |
| `ADMINER_PORT` | 8080 | Adminer |
| `DB_PORT` / `POSTGRES_PORT` | 5432 | Local PostgreSQL; values must match |

Required runtime keys are `CEN_FLAVOR`, `ENVIRONMENT`, `PROJECT_NAME`, all port keys,
`POSTGRES_*`, the four `OAUTH2_PROXY_*` credentials, `OAUTH2_PROXY_COOKIE_SECURE`, the five
`DEX_TEST_USER_*` fields, `PLAYWRIGHT_EXTERNAL_SERVER`, and telemetry. `VITE_API_URL` and
`BACKEND_CORS_ORIGINS` remain empty for same-origin proxy routing.

The marker values `changethis` are intentionally invalid. On the first
`pnpm run dev`, strong `OAUTH2_PROXY_CLIENT_SECRET`, `OAUTH2_PROXY_COOKIE_SECRET`, and
`OAUTH2_PROXY_UPSTREAM_PASSWORD` values are generated into that checkout's ignored `.env`.
Missing, example, or weak secrets are refused in every environment. Each checkout therefore has
a different private proxy/backend credential.

Dex is a local-only test IdP pinned as
`dexidp/dex:v2.45.1-distroless@sha256:8bfd667b384c2a2555c355c58c167e11127d2ea1a3711f1c246e4d7c5528eb2a`.
oauth2-proxy is pinned as
`quay.io/oauth2-proxy/oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561`.

### Bundled Dex or an external IdP

Leaving `OAUTH2_PROXY_OIDC_ISSUER_URL` blank uses the bundled Dex fixture with no additional
configuration. To use a corporate issuer instead, set these existing local-development keys in
`.env`:

```dotenv
OAUTH2_PROXY_CLIENT_ID=your-client-id
OAUTH2_PROXY_CLIENT_SECRET=your-client-secret
OAUTH2_PROXY_OIDC_ISSUER_URL=https://idp.example/oidc
OAUTH2_PROXY_REDIRECT_URL=http://localhost:4180/oauth2/callback
OAUTH2_PROXY_WELL_KNOWN_URL=https://idp.example/oidc/.well-known/openid-configuration
OAUTH2_PROXY_COOKIE_DOMAIN=localhost
```

Only the issuer is required; redirect defaults to the local proxy callback, discovery defaults to
`<issuer>/.well-known/openid-configuration`, and cookie domain remains host-only when blank. The
supervisor validates the discovery document and passes its authorization, token, and JWKS
endpoints to the pinned proxy. With an external issuer, Dex is neither started nor assigned a
local port. Register the exact redirect URL with the IdP.

## Authentication and logout

Open `http://localhost:4180`; unauthenticated requests redirect through `/oauth2/sign_in` to
Dex. The proxy owns the secure session cookie and sends normalized identity to FastAPI only with
the private Basic credential. The backend rejects spoofed forwarded headers, direct browser
bearer tokens, and an incorrect seam password.

Logout routes through `/oauth2/sign_out` and ends the proxy session. It does **not** terminate
the upstream IdP SSO session. Returning to login can silently authenticate while the Dex/external
IdP session remains active; fully ending SSO requires the provider's logout/session controls.

## Migrate on start and shutdown

With `MIGRATE_ON_START=true`, backend startup acquires PostgreSQL advisory lock `7461001`, upgrades
to the checkout's Alembic heads, verifies exact head equality, and seeds before readiness.
`MIGRATION_LOCK_TIMEOUT_SECONDS` defaults to 60. With migration disabled, exact-head checking
still runs. Lock timeout, unreachable database, broken migration, or any extra/missing revision
aborts startup and readiness.

One Ctrl-C gives children up to five seconds, then kills survivors and bounds Compose teardown;
worst case is about 12 seconds. A second Ctrl-C escalates immediately. The database volume is
preserved.

## Tests, generation, and troubleshooting

```bash
pnpm run verify
pnpm run test:deploy
```

Backend tests use a disposable Testcontainers PostgreSQL instance and ignore `.env`. Playwright
must traverse real Dex and oauth2-proxy; use the commands in `frontend/README.md`. Native browser
launch may be blocked locally, so the container command is the supported fallback.

On Podman, give the machine more memory than the 2 GiB default before running the containerized
Playwright suite: several parallel Chromium workers alongside PostgreSQL can exhaust it, and the
kernel then OOM-kills the database mid-run. Either `podman machine set --memory 8192` (stop and
restart the machine afterwards) or run the suite with `-- --workers=1`.

Use `pnpm run generate-client` after API changes and never edit generated client/route files.
Occupied ports are reported up front. For missing `backend/.venv`, rerun
`uv sync --project backend`; for missing frontend packages, rerun `pnpm install`.
Use the detected Compose command for logs. If proxy startup reports that Vite is unreachable,
check the detected runtime: Docker Desktop and Rancher Desktop use `host.docker.internal`, Podman
uses `host.containers.internal`, and native Linux Docker uses the host-gateway mapping.
