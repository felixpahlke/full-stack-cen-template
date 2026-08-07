# Stateless FastAPI backend

This backend has no database, migrations, frontend, user accounts, or token handling. Its secured
router uses the configured `X-API-Key` value.

## Install and run

From the repository root:

```bash
uv sync --project backend
cp .env.example .env
npm run dev
```

The root npm facade is the supported development interface. Docker is only needed when explicitly
building the production image.

## Layout

- `app/models.py`: Pydantic request and response models
- `app/api/routes/`: API route modules
- `app/api/main.py`: secured and public router registration
- `app/core/config.py`: root-anchored environment settings
- `app/main.py`: application factory and lazy FastAPI facade
- `app/tests/`: API and factory tests
- `tests/`: flavor telemetry tests

Add shared behavior outside route handlers where it improves clarity, register routes in
`app/api/main.py`, and cover authorization and response behavior with focused tests.

## Quality gate

```bash
npm run verify
```

This runs Ruff across the full backend and plain pytest without Docker or `.env`.

## Production image

The unchanged production image can be built explicitly from the repository root:

```bash
docker build -f backend/Dockerfile backend
```
