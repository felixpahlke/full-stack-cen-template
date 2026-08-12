# Migrating an existing oauth-proxy-custom-ui checkout

## Move an older checkout to the pnpm workspace

After updating an npm-based checkout, remove both old installs and lockfiles, then install the
root workspace once:

```bash
rm -rf node_modules frontend/node_modules
rm -f package-lock.json frontend/package-lock.json
corepack enable pnpm
pnpm install
```

Do not run a second install in `frontend`; the root workspace install includes it.

This release replaces the Compose application-process loop with native Uvicorn/Vite supervised by
`pnpm run dev`. The separate backend/frontend/proxy artifacts remain; the backend image now starts
Uvicorn with the `app.main:create_app` factory.

```bash
corepack enable pnpm
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

Existing `.env` files must gain native ports, Dex test-user settings,
`OAUTH2_PROXY_UPSTREAM_PASSWORD`, `MIGRATE_ON_START`, and
`MIGRATION_LOCK_TIMEOUT_SECONDS`. Marker proxy secrets are intentionally unusable and are replaced
with strong per-checkout values on first local startup. Do not copy a seam credential between
checkouts.

The previous local external-IdP keys are supported again. Leave
`OAUTH2_PROXY_OIDC_ISSUER_URL` blank for bundled Dex, or set it with
`OAUTH2_PROXY_REDIRECT_URL`, `OAUTH2_PROXY_WELL_KNOWN_URL`, and
`OAUTH2_PROXY_COOKIE_DOMAIN` as needed for AppID, Keycloak, or another issuer. Existing `.env`
files therefore work without editing Compose; see [development.md](development.md).

## Backend extension API compatibility

New extension code should prefer the injectable factories:

```python
from app.core.config import get_settings
from app.core.db import get_engine
from app.main import create_app

settings = get_settings()
engine = get_engine()
app = create_app(settings=settings, engine=engine)
```

Existing `from app.core.config import settings`, `from app.core.db import engine`, and
`from app.main import app` statements remain supported as lazy compatibility exports. The exported
`app` is the actual configured `FastAPI` instance, so router inclusion, middleware, exception
handlers, route inspection, and OpenAPI customization operate on the served application. Importing
`app.main` without requesting `app` still constructs no settings. Both `init_db(session)` and the
injected `init_db(session, settings)` form remain accepted.

## Frontend extension compatibility

`ThemeProvider` again accepts `defaultTheme`. Its `resolvedTheme` field is preferred; the previous
`activeTheme` field remains as a deprecated alias. The provider again applies an explicit
`light` DOM class as well as `dark`, restoring the contract used by custom styles.

Native Playwright runs no longer rewrite `localhost`. Container runs use
`PLAYWRIGHT_CONTAINER=true` through the provided wrapper. Biome now enables the available ESLint
equivalents; [known React Hooks coverage gaps](lint-coverage.md) are documented explicitly.

## Adopting an old OpenShift deployment

Back up PostgreSQL, then run `./scripts/oc-deploy.sh --adopt-legacy-resources` against the existing
project. The deployer verifies the exact legacy set, refuses ambiguous or partially labeled
objects, prints every resource, and changes labels only after
`adopt <PROJECT_NAME>/<APP_NAME>`. Do not bulk-label the namespace. A later PostgreSQL credential
change has its own typed destructive reset; adoption itself never deletes data.

Compose now runs PostgreSQL, Adminer, pinned Dex, and pinned oauth2-proxy. Uvicorn and Vite run on
the host. Browser entry is now explicitly `http://localhost:4180`. The backend trusts only the
private Basic identity seam. Proxy sign-out ends its cookie but does not end the IdP SSO session.

Breaking changes include pnpm-only JavaScript tooling, new host prerequisites, preflight port
refusal, exact Alembic-head startup checks, and containerized real-proxy Playwright. Production
images remain separate and unchanged in topology.

Blank OpenShift branch filters now resolve to `oauth-proxy-custom-ui` and must exist remotely before
BuildConfigs are created. Legacy production resources require the verified adoption flow above.

Rollback is available at `pre-modernization/oauth-proxy-custom-ui`:

```bash
git switch --detach pre-modernization/oauth-proxy-custom-ui
```

Create a recovery branch rather than overwriting work. Back up PostgreSQL before code rollback if
new migrations ran; switching code does not reverse schema changes.
