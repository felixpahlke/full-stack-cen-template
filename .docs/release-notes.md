# Release notes — OAuth modernization

Development now uses `npm run dev`: PostgreSQL, Adminer, pinned Dex, and pinned oauth2-proxy run
in Compose while Uvicorn and Vite run natively. Local marker secrets are replaced by strong
per-checkout credentials. The backend accepts identity only across the private Basic seam.

Migrations serialize during backend startup and exact bundled heads are required for readiness.
Tests are hermetic; OAuth Playwright traverses the real issuer/proxy path and has a lockfile-matched
container wrapper.

Deployment now uses strict two-label ownership, exact secret recreation, project-private OAuth
application workloads in Code Engine, and ready-before-switch staged OpenShift ingress. Real
cluster smoke testing is still pending; both deployment guides include the required checklist.

See [migration-guide.md](migration-guide.md). Rollback tag: `pre-modernization/oauth-proxy`.
