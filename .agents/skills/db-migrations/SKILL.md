---
name: db-migrations
description: Create, inspect, apply, and recover Alembic migrations for the SQLModel database while preserving exact-head startup checks.
---

# Database migrations

Schema truth is the `table=True` classes in `backend/app/tables.py`; revisions live in
`backend/app/alembic/versions/`. Keep the development database running while autogenerating.
Run `prepare-workstation` first when the checkout is not ready; `npm run dev` starts the database.

## Normal flow

1. Change the SQLModel table definition.
2. Wait for the database, then require
   `uv run --project backend alembic -c backend/alembic.ini current --check-heads` to pass.
3. `npm run db:revision -- -m "<short description>"`.
4. Read the new revision's `upgrade()` and `downgrade()`. Confirm constraints, indexes, nullability,
   foreign keys, data backfills, and destructive operations match the intent.
5. `npm run db:migrate`.
6. `uv run --project backend alembic -c backend/alembic.ini current --check-heads`.
7. Run the affected backend tests and `npm run verify`.

Never hand-edit a revision that any shared or deployed database has applied. Repair forward with a
new revision. A local generated-but-unapplied revision may be discarded and regenerated.

Production startup in `backend/app/startup.py` serializes migrations with a PostgreSQL advisory
lock. `MIGRATE_ON_START=true` upgrades then verifies exact head; `false` still verifies exact head.
A lock timeout or head mismatch is a failed release, not a condition to bypass.

For local rollback testing, use Alembic `downgrade -1`, inspect the schema, then upgrade to `head`
again. Do not downgrade a shared environment unless an explicit recovery plan requires it.
