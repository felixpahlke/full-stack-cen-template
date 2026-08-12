# Changelog

## Unreleased — modernization

- Moved JavaScript tooling to pnpm with a root lockfile and consistent root commands.
- Added pnpm 10.29.3 and Biome 2.5.4 as the JavaScript toolchain, plus mypy ≥1.18 and
  Testcontainers ≥4.13 for backend verification.
- Replaced the Compose application loop with `pnpm dev`: Uvicorn runs natively while Compose
  provides PostgreSQL and Adminer.
- Removed obsolete frontend, local-user, and ownership residue from the API-only flavour.
- Made backend tests reproducible with disposable PostgreSQL and serialized startup migrations
  across replicas.
- Hardened Code Engine and OpenShift deployment ownership, secrets, cleanup, and topology checks.

The API-key boundary and backend-only production image remain. Existing projects should follow the
[migration guide](.docs/migration-guide.md).
