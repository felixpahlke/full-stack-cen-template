# Release notes — development modernization

Development now starts with `npm run dev`. Only PostgreSQL and Adminer run in Compose; FastAPI
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
Strict mypy checking is part of the canonical `npm run check` and `npm run verify` gates.

Theme extension compatibility is restored: `defaultTheme` works again, `actualTheme` remains as a
deprecated alias of `resolvedTheme`, and old `carbon-theme` preferences migrate on first load. The
intentional Carbon palette is now `g10`/`g90` instead of `white`/`g100`, which visibly changes
surface and contrast tokens. CarbonCN scaffolding is restored for the Tailwind 4 foundation.

Playwright rewrites `localhost` only in the documented container flow. Biome now enables the
available ESLint equivalents, while the remaining React Hooks 7 gaps are listed in
[lint-coverage.md](lint-coverage.md) instead of being described as parity.

Production still uses separate backend and nginx frontend images. Real Code Engine and
OpenShift smoke tests remain pending; the required maintainer checklist is included in both
deployment guides.

Existing consumers should follow [migration-guide.md](migration-guide.md). The rollback point is
`pre-modernization/local-auth`.
