# Changelog

## Unreleased — modernization

- Moved JavaScript tooling to one pnpm workspace with a root lockfile and pinned dependencies.
- Replaced the Compose application loop with `pnpm dev`: Uvicorn and Vite run natively while
  Compose provides PostgreSQL and Adminer.
- Made generated-code checks and tests reproducible with offline generation, disposable PostgreSQL,
  and container-compatible Playwright.
- Serialized startup migrations across replicas and require the database to match the bundled
  Alembic revision before serving.
- Hardened Code Engine and OpenShift deployment ownership, secrets, cleanup, and rollouts.

The local-auth boundary, Carbon UI, and separate backend/frontend production images remain.
Existing projects should follow the [migration guide](.docs/migration-guide.md).
