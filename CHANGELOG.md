# Changelog

## 2026-08-12 — Modernization

- Moved JavaScript tooling to one pnpm workspace with a root lockfile and pinned dependencies.
- Updated React 19.1 → 19.2, TanStack Query 5.81 → 5.101, Router 1.125 → 1.170,
  Tailwind CSS 3.4 → 4.3, Zod 3.25 → 4.4, Lucide 0.525 → 1.30, Vite 8.0 → 8.2,
  TypeScript 5.8 → 5.9, Playwright 1.53 → 1.62, and OpenAPI TS 0.92 → 0.99; the Radix
  component set was refreshed across its 1.x/2.x lines.
- Replaced ESLint/Prettier with Biome 2.5.4 and added mypy ≥1.18 and Testcontainers ≥4.13.
- Replaced the Compose application loop with `pnpm dev`: Uvicorn and Vite run natively while
  Compose provides PostgreSQL, Adminer, Dex, and oauth2-proxy.
- Strengthened the OAuth boundary with a private backend credential, opaque identity subjects, and
  pinned local authentication images.
- Made tests reproducible with disposable PostgreSQL and a real-proxy containerized Playwright flow.
- Serialized startup migrations across replicas and hardened Code Engine and OpenShift rollouts.

The OAuth/OIDC boundary, shadcn/ui, and separate production images remain. Existing projects
should follow the [migration guide](.docs/migration-guide.md).
