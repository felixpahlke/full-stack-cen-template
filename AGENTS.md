# Working conventions

This is the Carbon UI, oauth2-proxy flavor of the FastAPI/SQLModel template. Preserve its proxy
authentication boundary, PostgreSQL backend, Carbon UI, and separate production images.

## Invariants

- Trust proxy identity only after the private Basic credential validates. Never add a browser
  bearer-token path or trust raw forwarded identity headers.
- Treat the identity subject as an opaque string, not necessarily a UUID. Keep OAuth entry and
  logout proxy-owned; proxy logout does not end the upstream IdP SSO session.
- Keep example and weak secrets unusable in every environment; never hardcode credentials.
- Keep SQLModel tables, API schemas, CRUD, routes, and settings in their existing modules. Use
  dependency injection and keep database logic out of routes.
- Schema startup must reach the exact bundled Alembic head, including when
  `MIGRATE_ON_START=false`.
- Protected pages stay under `frontend/src/routes/_layout`; use TanStack Query and the generated
  client. Never hand-edit `frontend/src/client` or `frontend/src/routeTree.gen.ts`.
- Preserve IBM Carbon and the Tailwind token bridge. Use npm only and exact-pin direct dependencies.

## Working guides

Use the task checklists in `.agents/skills/`; key references are `.docs/development.md`,
`.docs/maintenance.md`, `.docs/oc-deployment.md`, and `.docs/ce-deployment.md`. Cross-flavor
maintainers must also read `cen-template-maintenance`.
