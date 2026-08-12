---
name: add-resource
description: Add a complete SQLModel CRUD API resource with an Alembic migration, thin FastAPI routes, and hermetic tests; this branch has no frontend.
---

# Add a resource

Use `Item` as the working reference; read every file named below before editing. Decide the
singular/plural names, fields and constraints, and operations. This API-key flavor has no local
users or ownership model; do not add one. Keep database work in `backend/app/crud.py`, not routes.

If the checkout is not prepared, run `prepare-workstation`. Start `pnpm run dev` and keep it running
before the migration step.

## Backend

1. Add the `table=True` class to `backend/app/tables.py`. Use a UUID primary key and model only the
   resource's own fields, as `Item` does.
2. Add distinct `Base`, `Create`, `Update`, `Public`, and plural-public API models to
   `backend/app/models.py`. Keep database-only fields out of create/update input.
3. Add typed, keyword-only persistence functions to `backend/app/crud.py`: create, list/count,
   get, update, and delete as needed.
4. With the development database running, create and inspect the migration:

   ```bash
   uv run --project backend alembic -c backend/alembic.ini current --check-heads
   pnpm run db:revision -- -m "add <resources>"
   pnpm run db:migrate
   uv run --project backend alembic -c backend/alembic.ini current --check-heads
   ```

   Read both `upgrade()` and `downgrade()` before applying. Never edit an applied revision.
5. Add a thin router at `backend/app/api/routes/<resources>.py`; inject `SessionDep`, call CRUD
   functions, and declare response models and status codes. Register it under the existing
   API-key-protected router in `backend/app/api/main.py`.
6. Update existing exact API inventories in `backend/app/tests/api/routes/test_contract.py` and
   `backend/app/tests/core/test_config.py`; these intentionally fail when routes change.
7. Add route coverage under `backend/app/tests/api/routes/` and helper fixtures under
   `backend/app/tests/utils/` when useful. Cover create/list/read/update/delete, validation, API-key
   authentication, and not-found behavior. Tests use disposable PostgreSQL and ignore `.env`.

Finish with `pnpm run verify`. Exercise one authenticated create/list API round trip. Stop here:
this branch intentionally has no frontend, generated client, or page.
