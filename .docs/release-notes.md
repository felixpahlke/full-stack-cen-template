# Release notes — OAuth modernization

Development now uses `pnpm run dev`: PostgreSQL, Adminer, pinned Dex, and pinned oauth2-proxy run
in Compose while Uvicorn and Vite run natively. Local marker secrets are replaced by strong
per-checkout credentials. The backend accepts identity only across the private Basic seam.

Migrations serialize during backend startup and exact bundled heads are required for readiness.
Tests are hermetic; OAuth Playwright traverses the real issuer/proxy path and has a lockfile-matched
container wrapper.

Bundled Dex remains the zero-configuration issuer, while local external OIDC development is
restored through `OAUTH2_PROXY_OIDC_ISSUER_URL`, `OAUTH2_PROXY_REDIRECT_URL`,
`OAUTH2_PROXY_WELL_KNOWN_URL`, and `OAUTH2_PROXY_COOKIE_DOMAIN`. The supervisor validates and
honors those values without Compose edits and does not start Dex for an external issuer.

The backend image now runs `uvicorn app.main:create_app --factory`. The compatibility `app`,
`settings`, and `engine` exports are lazy factory products rather than shells or eager globals, and
strict mypy checking is part of the canonical `pnpm run check` and `pnpm run verify` gates.

Frontend compatibility is restored: `ThemeProvider` accepts `defaultTheme`, keeps deprecated
`actualTheme` beside `resolvedTheme`, and migrates the old `carbon-theme` preference. CarbonCN
scaffolding is restored for Tailwind 4. The intentional Carbon palette change to `g10`/`g90` is
documented, and the container-only Playwright resolver is now explicitly gated. Biome covers its
stable ESLint equivalents; remaining React Hooks gaps are documented in
[lint-coverage.md](lint-coverage.md).

Deployment now uses strict two-label ownership, exact secret recreation, project-private OAuth
application workloads in Code Engine, and ready-before-switch staged OpenShift ingress. Real
cluster smoke testing is still pending; both deployment guides include the required checklist.

See [migration-guide.md](migration-guide.md). Rollback tag: `pre-modernization/oauth-proxy`.
