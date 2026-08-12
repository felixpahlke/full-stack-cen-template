# Changelog

## Unreleased — development modernization

- Replaced the Compose application-process loop with `pnpm run dev`: PostgreSQL/Adminer stay in
  Compose while Uvicorn/Vite run natively with reload.
- Added a consistent root pnpm facade for development, quality, tests, builds, migrations, client
  generation, and deployment mocks.
- Made backend tests hermetic with Testcontainers and added container-compatible Playwright.
- Added serialized migrate-on-start with exact Alembic-head verification.
- Updated and pinned the frontend toolchain; `pnpm audit` reports zero vulnerabilities.
- Hardened Code Engine and OpenShift reconciliation with two-label ownership and staged ingress.

See [.docs/migration-guide.md](.docs/migration-guide.md) for consumer steps and rollback.
