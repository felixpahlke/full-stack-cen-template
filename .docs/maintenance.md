# Maintaining the branch variants

The six long-lived branches are product variants. Shared changes start on `local-auth`, are
committed there, and are then merged with `git merge local-auth --no-commit` into each target.
Resolve conflicts by preserving the target's UI, authentication, route, database, and deployment
topology. Use descriptive target commits rather than generic merge messages.

| Branch | UI | Authentication | Database |
| --- | --- | --- | --- |
| `local-auth` | Carbon | Local users/JWT | PostgreSQL |
| `local-auth-custom-ui` | shadcn/ui | Local users/JWT | PostgreSQL |
| `oauth-proxy` | Carbon | oauth2-proxy identity seam | PostgreSQL |
| `oauth-proxy-custom-ui` | shadcn/ui | oauth2-proxy identity seam | PostgreSQL |
| `backend-only` | None | API key | PostgreSQL |
| `backend-only-no-db` | None | API key | None |

## Guardrails

- Carbon branches stay Carbon; custom-UI branches stay shadcn/ui.
- Local-auth, OAuth, and API-key authorization surfaces must not leak into one another.
- OAuth identity subjects remain opaque strings and the private Basic seam remains proxy-only.
- Backend-only stays frontend-free. The no-database branch stays free of Compose, Alembic,
  persistence packages, and database settings.
- Shared deployment script bodies stay identical. Branch topology comes from
  `scripts/deploy-flavor.conf`, not a runtime-selected file tree.
- Frontend generated files are never edited. Run `npm run generate-client` on the branch after an
  exposed API or route change.
- Keep telemetry comments and branch-specific frontend/backend telemetry variable names.

## Validation

Install dependencies using that branch's root documentation, then run:

```bash
npm run verify
npm run test:deploy
```

For frontend branches, also run the documented Playwright flow and `npm --prefix frontend audit`.
For backend-only-no-db, prove `DOCKER_HOST=unix:///nonexistent npm run verify`. Build the relevant
production image(s) when Docker or deployment behavior changes. Review `git diff --cached` before
committing each target.

If a branch switch leaves dependencies stale, rerun `npm ci`, `npm ci --prefix frontend` when the
frontend exists, and `uv sync --project backend`. Development application processes are native;
only documented backing/auth services use Compose.
