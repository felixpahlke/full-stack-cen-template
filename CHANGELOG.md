# Changelog

## Unreleased — modernization

- Moved JavaScript tooling to pnpm with a root lockfile and consistent root commands.
- Added pnpm 10.29.3 and Biome 2.5.4 as the JavaScript toolchain, plus mypy ≥1.18 for strict
  backend type checking.
- Added a native `pnpm dev` loop and kept normal development and verification container-free.
- Removed obsolete frontend, database, migration, password/JWT, and token-printer residue.
- Made backend tests isolated and reproducible without Docker or PostgreSQL.
- Hardened Code Engine and OpenShift deployment ownership, secrets, cleanup, and topology checks.

The stateless API-key boundary and backend-only production image remain. Existing projects should
follow the [migration guide](.docs/migration-guide.md).
