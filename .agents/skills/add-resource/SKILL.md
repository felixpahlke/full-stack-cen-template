---
name: add-resource
description: Add a complete SQLModel CRUD resource with Alembic migration, FastAPI routes and tests, generated TypeScript client, and shadcn frontend page.
---

# Add a resource

Use `Item` as the working reference; read every file named below before editing. Decide the
singular/plural names, fields and constraints, whether records are user-owned, and whether a UI is
required. User ownership is the default. Keep database work in `backend/app/crud.py`, not routes.

If the checkout is not prepared, run `prepare-workstation`. Start `npm run dev` and keep it running
before the migration step.

## Backend

1. Add the `table=True` class to `backend/app/tables.py`. Use a UUID primary key. For user-owned
   data, add a non-null `owner_id` foreign key and quoted SQLModel relationships as `Item` does.
2. Add distinct `Base`, `Create`, `Update`, `Public`, and plural-public API models to
   `backend/app/models.py`. Keep database-only fields out of create/update input.
3. Add typed, keyword-only persistence functions to `backend/app/crud.py`: create, list/count,
   get, update, and delete as needed. Scope non-superuser queries to `current_user.id`.
4. With the development database running, create and inspect the migration:

   ```bash
   uv run --project backend alembic -c backend/alembic.ini current --check-heads
   npm run db:revision -- -m "add <resources>"
   npm run db:migrate
   uv run --project backend alembic -c backend/alembic.ini current --check-heads
   ```

   Read both `upgrade()` and `downgrade()` before applying. Never edit an applied revision.
5. Add a thin router at `backend/app/api/routes/<resources>.py`; inject `SessionDep` and
   `CurrentUser`, call CRUD functions, declare response models, and return the existing ownership
   failure status consistently. Register it in `backend/app/api/main.py`.
6. Add route coverage under `backend/app/tests/api/routes/` and helper fixtures under
   `backend/app/tests/utils/` when useful. Cover create/list/read/update/delete, validation,
   authentication, and a second user's ownership boundary. Tests use disposable PostgreSQL.

## Generated client and shadcn UI

1. Run `npm run generate-client`; commit its changes, but never edit `frontend/src/client` or
   `frontend/src/routeTree.gen.ts` by hand.
2. Build the page under `frontend/src/routes/_layout/<resources>.tsx`. Follow the existing Items
   split: route file plus focused components under `frontend/src/components/<resources>/`.
3. Use the generated service/types with TanStack Query. Include stable query keys, pagination
   where lists can grow, mutation error handling, and invalidation after writes.
4. Compose the existing shadcn/ui primitives under `frontend/src/components/ui`; use semantic
   Tailwind theme classes rather than hardcoded colors. Add the navigation entry to
   `frontend/src/components/common/Header.tsx`.

During template maintenance, add the same page to the Carbon `local-auth` twin; its parity gate
deliberately keeps both route surfaces equal.

Finish with `npm run generate-client` and `npm run verify`. Exercise one create/list round trip.
