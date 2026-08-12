# Changelog

## Unreleased — modernization

- Moved JavaScript tooling to one pnpm workspace with a root lockfile and pinned dependencies.
- Replaced the Compose application loop with `pnpm dev`: Uvicorn and Vite run natively while
  Compose provides PostgreSQL, Adminer, Dex, and oauth2-proxy.
- Strengthened the OAuth boundary with a private backend credential, opaque identity subjects, and
  pinned local authentication images.
- Made tests reproducible with disposable PostgreSQL and a real-proxy containerized Playwright flow.
- Serialized startup migrations across replicas and hardened Code Engine and OpenShift rollouts.

The OAuth/OIDC boundary, shadcn/ui, and separate production images remain. Existing projects
should follow the [migration guide](.docs/migration-guide.md).
