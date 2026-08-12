# Working conventions

This is the stateless backend-only, API-key flavor of the FastAPI template. Preserve its
container-free development path and backend-only production image.

## Invariants

- Preserve API-key authentication. Do not add browser bearer-token or proxy identity surfaces.
- Keep the branch free of frontend, database, Compose, Alembic, persistence packages, local users,
  and ownership models.
- Keep API models in `backend/app/models.py`, thin routes in `backend/app/api/routes/`, registration
  in `backend/app/api/main.py`, and reusable business logic outside routes.
- Keep example and weak secrets unusable in every environment; never hardcode credentials.
- Only health checks belong outside the API-key-protected router.
- Do not introduce generated-client, route-tree, Playwright, or frontend files.
- Use pnpm only and exact-pin direct dependencies.

## Working guides

Use the task checklists in `.agents/skills/`. Start with `prepare-workstation`, `add-resource`, the
deploy/debug pair for the target, or `update-from-template`; database/page skills do not apply.
Key references are `.docs/development.md`, `.docs/maintenance.md`, and the deployment guides in
`.docs/`; cross-flavor maintainers must also read `cen-template-maintenance`.
