# Migrating an existing backend-only-no-db checkout

Development now runs Uvicorn natively under the root npm supervisor. The obsolete Compose file
and database/auth dependency residue are gone. The backend image now starts Uvicorn with the
`app.main:create_app` factory.

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

Node/npm, Python, and uv are host prerequisites. Docker is no longer needed for development,
checks, or tests. Root `API_PORT` is preflighted before startup. There are intentionally no
database, migration, frontend, generated-client, or Playwright commands.

## Backend extension API compatibility

New extension code should prefer `create_app` and `get_settings`. Existing
`from app.main import app` and `from app.core.config import settings` imports remain supported as
lazy factory-backed exports. The exported `app` is the actual configured `FastAPI` instance, so
router inclusion, middleware, exception handlers, route inspection, and OpenAPI customization
operate on the served application. Importing `app.main` without requesting `app` still constructs
no settings. This flavor intentionally has no `engine` export.

## Adopting an old OpenShift deployment

Run `./scripts/oc-deploy.sh --adopt-legacy-resources` against the existing project. The deployer
fingerprints and prints the exact backend-only legacy set, refuses ambiguity or partial labels, and
changes ownership only after `adopt <PROJECT_NAME>/<APP_NAME>`. It does not adopt database or
frontend resources.

Breaking changes: the old Compose application loop is removed; npm is the only JavaScript tool;
the unused persistence/password/JWT packages and token-printer residue are removed; the root
command facade is canonical. Production topology is otherwise unchanged.

Blank OpenShift branch filters now resolve to `backend-only-no-db` and must exist remotely before
the BuildConfig is created. Legacy resources require the verified adoption flow above.

Rollback tag: `pre-modernization/backend-only-no-db`.

```bash
git switch --detach pre-modernization/backend-only-no-db
```

Create a recovery branch instead of overwriting work. There is no schema rollback because this
branch has no database.
