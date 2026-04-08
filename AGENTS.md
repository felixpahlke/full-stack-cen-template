# Overview

Project uses [create-cen-app](https://github.com/felixpahlke/create-cen-app):

- **Backend:** FastAPI, UV package manager
- **Main Infrastructure:** Docker Compose, OAuth2 Proxy, OpenShift deployment

## Additional Skill Docs
- **`.agents/skills/cen-template-maintenance/SKILL.md`** - Maintain this repository across flavor branches, propagate canonical changes from `local-auth`, and preserve flavor-specific behavior during merges.

## Development with Docker

### Preparing the environment

Before starting the development environment, make sure:

- that the Backend Python environment is installed. If `backend/.venv` does not exist, execute:

```bash
cd backend && uv sync
```

- that the Python environment is selected. If not execute:

```bash
source backend/.venv/bin/activate
```

- that THIS application is up and running. See section: [Checking if Application is Running](#Checking-if-Application-is-Running). If another application is running, please shut that down first, before starting THIS application

### Developing the Application using Docker

The application is developed using Docker Compose with hot-reload support.
To start the application, run:

```bash
docker compose watch
```

To stop the application, run:

```bash
docker compose down
```

For restarting the application, run:

```bash
docker compose down
docker compose watch
```

To check the logs of a specific container, e.g. the backend run:

```bash
docker compose logs backend
```

**IMPORTANT:** If the user doesn't use Docker Desktop but container runtimes such as colima all commands using `docker compose` must be replaced by `docker-compose`.

### Checking if Application is Running

To verify if THIS specific application (not a sibling project) is running, check Docker containers:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Important:** Container names are prefixed with the project directory name. For example:

- If the project directory is `full-stack-cen-template`, containers will be named `full-stack-cen-template-backend-1`, etc.
  Always verify the container name prefix matches the current project directory to ensure you're checking the correct application instance.

# Backend Conventions/Rules:

## Important Files:

- **`backend/app/models.py`** - Pydantic API schemas (Create, Update, Public models)
- **`backend/app/api/routes/`** - API endpoints (one file per resource)
- **`backend/app/api/main.py`** - Router registration
- **`backend/app/core/config.py`** - Contains static values and encloses environment variables

## API Routes (`api/routes/`):

- Use dependency injection for shared resources and `current_user`
- Specify `response_model` and `status_code`
- Keep business logic in dedicated services or utility modules
- Register in `backend/app/api/main.py`

## Secrets and Environment Variables (`core/config.py`)

- All configuration and secrets are managed in `backend/app/core/config.py`
- Uses Pydantic `BaseSettings` to load from `.env` file
- Any key defined in `.env` MUST also exist in `.env.example`
- Any key in `.env` MUST be defined as a field in the `Settings` class in `backend/app/core/config.py`
- Type hints in `Settings` should match the value type in `.env`:
- Never hardcode secrets in code - always use `settings` object

# Essential Workflows

## Adding a New Backend API Endpoint

**Prerequisites:** Ensure the application is running before testing changes.

1. Add or update schemas in `backend/app/models.py` (Create, Update, Public) if new request/response shapes are needed.
2. Implement any supporting logic in shared modules (for example utilities under `backend/app/api/`).
3. Create or update the route file in `backend/app/api/routes/`.
4. Register the router in `backend/app/api/main.py`.
5. **Ensure that THIS app is running:** See section: [Checking if Application is Running](#Checking-if-Application-is-Running)
6. Add or update automated tests under `backend/app/tests/` to cover the new behavior.

# Common Mistakes to Avoid

- **DON'T** duplicate schema definitions—keep shared types in `backend/app/models.py`.
- **DON'T** put heavy business logic directly inside route handlers; factor it into helpers or services.
- **DON'T** forget to activate the virtual environment before running backend scripts or tests.
- **DON'T** mix up other applications that are running with THIS one. Make sure to verify the prefix of the containers. See section: [Checking if Application is Running](#Checking-if-Application-is-Running)
- **DON'T** forget that the API endpoints have a prefix which is defined in the `API_V1_STR` under `backend/app/core/config.py`
