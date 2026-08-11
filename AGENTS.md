# Working conventions

This is the Carbon UI, oauth2-proxy branch. Preserve the proxy authentication model, opaque
identity subject, private Basic seam, and separate frontend/backend production images.

## Setup and commands

```bash
npm ci
npm ci --prefix frontend
uv sync --project backend
cp .env.example .env
npm run dev
```

The root vocabulary is `dev`, `check`, `fix`, `test`, `build`, `verify`, `db:migrate`,
`db:revision`, and `test:deploy`. `npm run test:e2e:container` is the OAuth browser gate.
Docker Desktop, Rancher Desktop with the dockerd/moby backend, native Linux Docker, and Podman
with an available Compose provider are supported. Use Ctrl-C and verify containers for this
checkout are gone before switching branches.

## Backend and OAuth boundary

- Keep tables, schemas, CRUD, routes, and settings in their existing dedicated modules.
- Use dependency injection and keep database logic out of routes.
- Trust proxy identity only after the private Basic credential validates. Do not add a browser
  bearer-token path or trust raw forwarded headers.
- Treat the identity subject as an opaque string, not necessarily a UUID.
- Keep example/weak OAuth secrets unusable in every environment. Local marker values are replaced
  with strong per-checkout secrets by `npm run dev`.
- Schema changes use new Alembic revisions and root `db:*` commands. Exact-head verification is
  mandatory even when `MIGRATE_ON_START=false`.

## Frontend

- Preserve IBM Carbon and the existing Tailwind token bridge.
- Protected routes live under `frontend/src/routes/_layout`.
- Use TanStack Query and the generated client; never edit generated files manually.
- OAuth entry/logout must remain proxy-owned. Document that proxy logout does not end IdP SSO.
- Use npm only and keep direct dependencies exact-pinned.

## Verification

```bash
npm run verify
npm run test:deploy
```

Backend tests are hermetic Testcontainers tests. OAuth Playwright must use the real proxy/issuer
path; use the container wrapper if native Chromium is unavailable. See `.docs/development.md`,
`.docs/maintenance.md`, and `.agents/skills/cen-template-maintenance/SKILL.md`.
