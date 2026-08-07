# Migrating an existing local-auth checkout

This release replaces the Compose-watch development loop with a root npm supervisor. Production
Dockerfiles and the separate backend/frontend production images are unchanged.

## Upgrade

1. Commit or stash application changes and update to this branch.
2. Install the new native prerequisites: Node.js 20.19+, npm, Python 3.10–3.12, and uv.
3. Reinstall locked dependencies:

   ```bash
   npm ci
   npm ci --prefix frontend
   uv sync --project backend
   ```

4. Compare `.env` with `.env.example`. Add `API_PORT`, `WEB_PORT`, `DB_PORT`, `ADMINER_PORT`,
   `MIGRATE_ON_START=true`, and `MIGRATION_LOCK_TIMEOUT_SECONDS=60` as needed.
5. Start with `npm run dev`.

## Adopting an old OpenShift deployment

The hardened deployer does not infer ownership from names. Before the first production redeploy,
back up PostgreSQL and run:

```bash
./scripts/oc-deploy.sh --adopt-legacy-resources
```

The target project must already exist. The script verifies the matching legacy resource set,
refuses partially labeled or ambiguous same-name objects, and prints the exact adoption list.
Review it, then type `adopt <PROJECT_NAME>/<APP_NAME>`. No labels are applied if the flag is
omitted, a fingerprint differs, or the phrase is not exact. Do not bulk-label the namespace;
unknown resources intentionally remain outside the migration set.

If PostgreSQL initialization credentials changed too, the subsequent deploy stops before replacing
the application secret and requires a separate typed destructive reset. Adoption itself never
deletes or recreates the database.

Compose now runs only PostgreSQL and Adminer. Uvicorn and Vite run on the host, so host Python,
uv, Node, npm, and frontend dependencies are breaking new development prerequisites. Port
conflicts now fail before startup. Backend startup, rather than a separate shell step, owns
migration, exact-head verification, and initial-user seeding.

Generated client publication is offline and atomic. Backend tests create disposable PostgreSQL
containers rather than using the development database. Playwright may need the documented
container pattern when native browsers are blocked.

## Breaking changes

- The old Compose application-process workflow is removed; use `npm run dev`.
- npm is the only JavaScript package manager.
- Root commands are the supported interface for checks, tests, builds, migrations, and deploy
  mocks.
- Startup refuses remote development databases unless explicitly allowed.
- Startup refuses a schema that is not exactly at the checkout's Alembic heads.
- Ctrl-C shuts down native children and backing-service containers but preserves database data.
- Blank OpenShift branch filters now resolve to the checked-out flavor branch and must exist in the
  configured repository before BuildConfigs are created.
- Legacy OpenShift resources require the verified adoption flow above.

## Rollback

The pre-upgrade branch tip is tagged `pre-modernization/local-auth`. To inspect or restore it
without overwriting current work:

```bash
git switch --detach pre-modernization/local-auth
```

Create a recovery branch from that tag if rollback is required. Back up PostgreSQL first if a
new migration has been applied; code rollback does not reverse database migrations. Return to
the updated branch with `git switch local-auth` (or your consumer branch name).
