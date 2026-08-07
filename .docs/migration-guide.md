# Migrating an existing oauth-proxy checkout

This release replaces the Compose application-process loop with native Uvicorn/Vite supervised by
`npm run dev`. Production Dockerfiles and the separate backend/frontend/proxy artifacts remain.

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

Blank OpenShift branch filters now resolve to `oauth-proxy` and must exist remotely before
BuildConfigs are created. Legacy production resources require the verified adoption flow above.

Rollback is available at `pre-modernization/oauth-proxy`:

```bash
git switch --detach pre-modernization/oauth-proxy
```

Create a recovery branch rather than overwriting work. Back up PostgreSQL before code rollback if
new migrations ran; switching code does not reverse schema changes.
