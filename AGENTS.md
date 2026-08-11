# Working conventions

This is the stateless backend-only, API-key branch. Preserve the absence of frontend, database,
Compose, migrations, persistence packages, users, and bearer authentication.

## Setup and commands

```bash
npm ci
uv sync --project backend
cp .env.example .env
npm run dev
```

Supported root vocabulary is `dev`, `check`, `fix`, `test`, `build`, `verify`, and
`test:deploy`. `build` needs Docker or Podman; the rest are container-free. Database and frontend
commands do not exist by design.

Keep schemas in `backend/app/models.py`, routes in `backend/app/api/routes`, registration in
`backend/app/api/main.py`, and environment-backed settings in `backend/app/core/config.py`. Keep
routes thin, reuse helpers for real business logic, mirror `.env` keys in `.env.example`, and
never hardcode secrets.

Finish normal work with `DOCKER_HOST=unix:///nonexistent npm run verify` and
`npm run test:deploy`. Build the image only when relevant. See `.docs/development.md`,
`.docs/maintenance.md`, and the maintenance skill for cross-branch work.
