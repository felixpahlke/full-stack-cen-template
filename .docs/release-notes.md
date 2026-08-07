# Release notes — stateless backend modernization

Development and tests are now fully native and Docker-free. `npm run dev` runs reload-enabled
Uvicorn; the root command facade handles checks, tests, deploy mocks, and the optional Docker image
build. Obsolete database, Compose, and token-printer residue has been removed without changing the
public health or API-key example routes.

The backend image now runs `uvicorn app.main:create_app --factory`. Compatibility `app` and
`settings` exports are lazy factory products rather than shells or eager globals. Canonical checks
now include strict mypy, and backend tests once again print a coverage report and generate HTML
coverage output.

Deployment uses strict two-label ownership, fail-closed collisions, and topology absence checks.
Real cluster smoke tests remain pending; both deployment guides include the complete checklist.

See [migration-guide.md](migration-guide.md). Rollback tag:
`pre-modernization/backend-only-no-db`.
