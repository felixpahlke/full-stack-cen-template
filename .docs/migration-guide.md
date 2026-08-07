# Migrating an existing oauth-proxy-custom-ui checkout

This release replaces the Compose application-process loop with native Uvicorn/Vite supervised by
`npm run dev`. The separate backend/frontend/proxy artifacts remain; the backend image now starts
Uvicorn with the `app.main:create_app` factory.

```bash
npm ci
npm ci --prefix frontend
uv sync --project backend
cp .env.example .env
npm run dev
```

Existing `.env` files must gain native ports, Dex test-user settings,
`OAUTH2_PROXY_UPSTREAM_PASSWORD`, `MIGRATE_ON_START`, and
`MIGRATION_LOCK_TIMEOUT_SECONDS`. Marker proxy secrets are intentionally unusable and are replaced
with strong per-checkout values on first local startup. Do not copy a seam credential between
checkouts.

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

## Adopting an old OpenShift deployment

Back up PostgreSQL, then run `./scripts/oc-deploy.sh --adopt-legacy-resources` against the existing
project. The deployer verifies the exact legacy set, refuses ambiguous or partially labeled
objects, prints every resource, and changes labels only after
`adopt <PROJECT_NAME>/<APP_NAME>`. Do not bulk-label the namespace. A later PostgreSQL credential
change has its own typed destructive reset; adoption itself never deletes data.

Compose now runs PostgreSQL, Adminer, pinned Dex, and pinned oauth2-proxy. Uvicorn and Vite run on
the host. Browser entry is now explicitly `http://localhost:4180`. The backend trusts only the
private Basic identity seam. Proxy sign-out ends its cookie but does not end the IdP SSO session.

Breaking changes include npm-only JavaScript tooling, new host prerequisites, preflight port
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
