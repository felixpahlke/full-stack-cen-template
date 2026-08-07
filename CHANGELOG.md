# Changelog

## Unreleased — development modernization

- Added the native Uvicorn/root npm development loop; Compose now runs only PostgreSQL/Adminer.
- Removed dead local-user and item-ownership residue.
- Added hermetic Testcontainers tests and serialized exact-head migrate-on-start.
- Added a consistent command facade and production image `build` command.
- Hardened Code Engine/OpenShift ownership, secrets, cleanup, and topology absence checks.

See [.docs/migration-guide.md](.docs/migration-guide.md).
