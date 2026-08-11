# Working conventions

This is the backend-only, PostgreSQL, API-key flavor of the FastAPI/SQLModel template. Preserve its
frontend-free API and backend-only production image.

## Invariants

- Preserve API-key authentication. Do not add frontend, local users, ownership, proxy identity, or
  browser bearer-token surfaces.
- Keep SQLModel tables, API schemas, CRUD, routes, and settings in their existing modules. Use
  dependency injection and keep database logic out of routes.
- Keep example and weak secrets unusable in every environment; never hardcode credentials.
- Schema startup must reach the exact bundled Alembic head, including when
  `MIGRATE_ON_START=false`.
- Keep backend tests hermetic: disposable Testcontainers PostgreSQL or an explicitly safe test
  database, never the developer `.env` database.
- Do not introduce generated-client, route-tree, Playwright, or frontend files.
- Use npm only and exact-pin direct dependencies.

## Working guides

Use the task checklists in `.agents/skills/`. Start with `prepare-workstation`, `add-resource`,
`db-migrations`, the deploy/debug pair for the target, or `update-from-template`.
Key references are `.docs/development.md`, `.docs/maintenance.md`, and the deployment guides in
`.docs/`; cross-flavor maintainers must also read `cen-template-maintenance`.
