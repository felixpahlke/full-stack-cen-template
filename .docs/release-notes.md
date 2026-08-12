# Release notes — development modernization

Development now starts with `pnpm run dev`. Only PostgreSQL and Adminer run in Compose; FastAPI
and Vite run natively with reload/HMR. The first-run sequence, root commands, port contract,
shutdown behavior, migration ownership, hermetic tests, and Playwright container pattern are
documented in [development.md](development.md).

Backend startup serializes migration and seeding, verifies the database is at exactly the
Alembic heads bundled in the checkout, and refuses readiness on failure. Deployment scripts now
mutate or delete only resources bearing both the template managed-by label and the current
application instance label.

The backend image now runs `uvicorn app.main:create_app --factory`. The compatibility `app`,
`settings`, and `engine` exports are lazy factory products rather than shells or eager globals, so
existing extension code keeps working while module-only imports remain safe without `.env`.
Strict mypy checking is part of the canonical `pnpm run check` and `pnpm run verify` gates.

Frontend compatibility is restored: `ThemeProvider` accepts `defaultTheme`, retains deprecated
`activeTheme` beside `resolvedTheme`, and applies both `light` and `dark` DOM classes. The
container-only Playwright hostname rewrite is now explicitly gated by
`PLAYWRIGHT_CONTAINER=true`. Biome covers the stable equivalents of the former ESLint rules;
the remaining React Hooks gaps are documented in [lint-coverage.md](lint-coverage.md).

Production still uses separate backend and nginx frontend images. Real Code Engine and
OpenShift smoke tests remain pending; the required maintainer checklist is included in both
deployment guides.

Existing consumers should follow [migration-guide.md](migration-guide.md). The rollback point is
`pre-modernization/local-auth-custom-ui`.
