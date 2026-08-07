# Changelog

## Unreleased — development modernization

- Added a native Uvicorn/Vite supervisor with Compose-hosted PostgreSQL, Adminer, Dex, and
  oauth2-proxy.
- Replaced browser token forwarding with a private, per-checkout Basic Auth identity seam and
  pinned Dex/oauth2-proxy images by digest.
- Added hermetic Testcontainers tests and real-proxy containerized Playwright.
- Added serialized migrate-on-start with exact Alembic-head verification.
- Added the root npm command facade and zero-vulnerability frontend lock/overrides.
- Hardened Code Engine/OpenShift ownership, secrets, and staged OAuth ingress.

See [.docs/migration-guide.md](.docs/migration-guide.md).
