---
name: add-resource
description: Add a stateless API route with Pydantic models and tests; this branch has no database, migration, generated client, or frontend.
---

# Add an API resource

Use the existing example API as the working reference. Decide the route name, request/response
shape, validation constraints, and operations. This flavor has no database, persistence packages,
users, ownership model, generated client, or frontend; do not introduce them.

1. Add Pydantic request/response models to `backend/app/models.py`; do not add SQLModel table types.
2. Put reusable domain logic in a focused helper module under `backend/app/` when the route would
   otherwise contain business logic. Keep the route limited to HTTP translation and dependency use.
3. Add `backend/app/api/routes/<resource>.py` with an `APIRouter`, typed return values, response
   models, and explicit status behavior. Follow `example.py`.
4. Register the router under `secured_api_router` in `backend/app/api/main.py` so the existing
   `APIKeyDep` applies. Only health checks belong in the unsecured router.
5. Search existing tests for exact route/OpenAPI inventories and update them for the new surface.
6. Add `backend/app/tests/api/routes/test_<resource>.py`. Cover the success response, Pydantic
   validation, missing/wrong API keys, and meaningful error cases. Reuse `client` and
   `api_key_headers` from `backend/app/tests/conftest.py`.

Finish with `DOCKER_HOST=unix:///nonexistent npm run verify` and exercise one authenticated API
request. Stop there: no table, migration, CRUD persistence, generated client, or page applies.
