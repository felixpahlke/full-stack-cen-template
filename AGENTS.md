# Working conventions

This is the shadcn/ui, local-authentication flavor of the FastAPI/SQLModel template. Preserve its
local user and JWT model, custom UI identity, PostgreSQL backend, and separate production images.

## Invariants

- Keep SQLModel tables, API schemas, CRUD, routes, and settings in their existing modules. Use
  dependency injection and keep database logic out of routes.
- Preserve local user ownership and authorization boundaries. Do not replace them with proxy or
  API-key authentication.
- Keep example and weak secrets unusable in every environment; never hardcode credentials.
- Schema startup must reach the exact bundled Alembic head, including when
  `MIGRATE_ON_START=false`.
- Protected pages stay under `frontend/src/routes/_layout`; use TanStack Query and the generated
  client for API data.
- Never hand-edit `frontend/src/client` or `frontend/src/routeTree.gen.ts`; regenerate them.
- Preserve shadcn/ui and semantic Tailwind tokens. Use npm only and exact-pin direct dependencies.

## Working guides

Use the task checklists in `.agents/skills/`. Start with `prepare-workstation`, `add-resource`,
`add-page`, `db-migrations`, the deploy/debug pair for the target, or `update-from-template`.
Key references are `.docs/development.md`, `.docs/maintenance.md`, and the deployment guides in
`.docs/`; cross-flavor maintainers must also read `cen-template-maintenance`.
