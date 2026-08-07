# Migrating an existing backend-only-no-db checkout

Development now runs Uvicorn natively under the root npm supervisor. The obsolete Compose file
and database/auth dependency residue are gone. The production backend Dockerfile remains.

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

Node/npm, Python, and uv are host prerequisites. Docker is no longer needed for development,
checks, or tests. Root `API_PORT` is preflighted before startup. There are intentionally no
database, migration, frontend, generated-client, or Playwright commands.

Breaking changes: the old Compose application loop is removed; npm is the only JavaScript tool;
the unused persistence/password/JWT packages and token-printer residue are removed; the root
command facade is canonical. Production image behavior is otherwise unchanged.

Rollback tag: `pre-modernization/backend-only-no-db`.

```bash
git switch --detach pre-modernization/backend-only-no-db
```

Create a recovery branch instead of overwriting work. There is no schema rollback because this
branch has no database.
