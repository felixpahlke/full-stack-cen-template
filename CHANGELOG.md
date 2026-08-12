# Changelog

## Unreleased — modernization

- Moved JavaScript tooling to one pnpm workspace with a root lockfile and pinned dependencies.
- Updated React 19.1 → 19.2, Carbon React 1.85 → 1.113, Carbon Icons 11.62 → 11.85,
  TanStack Query 5.81 → 5.101, Router 1.125 → 1.170, Tailwind CSS 3.4 → 4.3, Zod 3.25 → 4.4,
  Vite 8.0 → 8.2, TypeScript 5.8 → 5.9, Playwright 1.53 → 1.62, and OpenAPI TS 0.92 → 0.99.
- Replaced ESLint/Prettier with Biome 2.5.4 and added mypy ≥1.18 and Testcontainers ≥4.13.
- Replaced the Compose application loop with `pnpm dev`: Uvicorn and Vite run natively while
  Compose provides PostgreSQL and Adminer.
- Made generated-code checks and tests reproducible with offline generation, disposable PostgreSQL,
  and container-compatible Playwright.
- Serialized startup migrations across replicas and require the database to match the bundled
  Alembic revision before serving.
- Hardened Code Engine and OpenShift deployment ownership, secrets, cleanup, and rollouts.

The local-auth boundary, Carbon UI, and separate backend/frontend production images remain.
Existing projects should follow the [migration guide](.docs/migration-guide.md).
