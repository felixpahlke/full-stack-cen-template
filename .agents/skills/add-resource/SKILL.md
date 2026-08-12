---
name: add-resource
description: Add a complete SQLModel CRUD resource with Alembic migration, FastAPI routes and tests, generated TypeScript client, and Carbon frontend page.
---

# Add a resource

Use `Item` as the working reference; read every file named below before editing. Decide the
singular/plural names, fields and constraints, whether records are identity-owned, and whether a UI
is required. Identity ownership is the default. Keep database work in `backend/app/crud.py`, not
routes. Treat the proxy subject as an opaque string; it is not necessarily a UUID.

If the checkout is not prepared, run `prepare-workstation`. Start `pnpm run dev` and keep it running
before the migration step.

## Backend

1. Add the `table=True` class to `backend/app/tables.py`. Use a UUID record key. For identity-owned
   data, add a non-null string `owner_id` as `Item` does; there is no local User table or foreign
   key in this flavor.
2. Add distinct `Base`, `Create`, `Update`, `Public`, and plural-public API models to
   `backend/app/models.py`. Keep database-only fields out of create/update input.
3. Add typed, keyword-only persistence functions to `backend/app/crud.py`: create, list/count,
   get, update, and delete as needed. Scope every owned query to `current_user.id`.
4. With the development database running, create and inspect the migration:

   ```bash
   uv run --project backend alembic -c backend/alembic.ini current --check-heads
   pnpm run db:revision -- -m "add <resources>"
   pnpm run db:migrate
   uv run --project backend alembic -c backend/alembic.ini current --check-heads
   ```

   Read both `upgrade()` and `downgrade()` before applying. Never edit an applied revision.
5. Add a thin router at `backend/app/api/routes/<resources>.py`; inject `SessionDep` and
   `CurrentUser`, call CRUD functions, declare response models, and return the existing ownership
   failure status consistently. Never accept browser bearer auth or raw identity headers; the
   existing dependency validates the private Basic seam first. Register in `backend/app/api/main.py`.
6. Add route coverage under `backend/app/tests/api/routes/`; keep reusable fixtures in the existing
   `backend/app/tests/conftest.py`. Cover create/list/read/update/delete, validation,
   authentication, a non-UUID subject, and a second subject's ownership boundary. Use the existing
   `identity_headers` fixture; tests use disposable PostgreSQL through the real auth dependency.

Update the pinned Alembic head and exact database inventory in `backend/app/tests/conftest.py`, plus
the API/OpenAPI inventories in `backend/app/tests/test_oauth_topology.py` and
`backend/app/tests/scripts/test_generate_openapi.py`.

## Generated client and Carbon UI

1. Run `pnpm run generate-client`; commit its changes, but never edit `frontend/src/client` or
   `frontend/src/routeTree.gen.ts` by hand.
2. Build the page under `frontend/src/routes/_layout/<resources>.tsx`. Follow the existing Items
   split: route file plus focused components under `frontend/src/components/<resources>/`.
3. Use the generated service/types with TanStack Query. Include stable query keys, pagination
   where lists can grow, mutation error handling, and invalidation after writes.
4. Use Carbon components and tokens; Tailwind is for layout and the existing token bridge. Add the
   navigation entry to `frontend/src/components/common/Header.tsx`.

Update the expected route list in `scripts/route-parity.test.mjs`. During template maintenance,
add the same page to the shadcn `oauth-proxy-custom-ui` twin.

Finish with `pnpm run generate-client` and `pnpm run verify`. Exercise one create/list round trip.
