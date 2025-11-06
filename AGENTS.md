# Overview
Project uses [create-cen-app](https://github.com/felixpahlke/create-cen-app):
- **Backend:** FastAPI, SQLModel, PostgreSQL, Alembic, UV package manager
- **Frontend:** React 19, TypeScript, Vite, TanStack Router/Query, IBM Carbon Design System
- **Main Infrastructure:** Docker Compose, OAuth2 Proxy, OpenShift deployment

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
- that the Frontend environment is installed. If `frontend/node_modules` does not exist, execture:
```bash
cd frontend && npm install
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
- If the project directory is `full-stack-cen-template`, containers will be named `full-stack-cen-template-backend-1`, `full-stack-cen-template-frontend-1`, etc.
Always verify the container name prefix matches the current project directory to ensure you're checking the correct application instance.

# Backend Conventions/Rules:

## Important Files:
- **`backend/app/tables.py`** - SQLModel DB models (with `table=True`)
- **`backend/app/models.py`** - Pydantic API schemas (Create, Update, Public models)
- **`backend/app/crud.py`** - Database operations
- **`backend/app/api/routes/`** - API endpoints (one file per resource)
- **`backend/app/api/main.py`** - Router registration
- **`backend/app/core/config.py`** - Contains static values and encloses environment variables

## Database Models (`tables.py`):
- Use `SQLModel` with `table=True`
- Use UUID for primary keys

## API Schemas (`models.py`):
- Use `Pydantic SQLModel with table=false`
- Create separate models for Create, Update, and Public
- Public models include all fields returned to client

## CRUD Operations (`crud.py`):
- Keep ALL database logic here
- Use keyword-only arguments (`*,`)
- Use type hints
- Handle session commit/refresh

## API Routes (`api/routes/`):
- Use dependency injection for `session` and `current_user`
- Specify `response_model` and `status_code`
- Call CRUD functions, don't write DB logic here
- Register in `backend/app/api/main.py`

## Secrets and Environment Variables (`core/config.py`)
- All configuration and secrets are managed in `backend/app/core/config.py`
- Uses Pydantic `BaseSettings` to load from `.env` file
- Any key defined in `.env` MUST also exist in `.env.example`
- Any key in `.env` MUST be defined as a field in the `Settings` class in `backend/app/core/config.py`
- Type hints in `Settings` should match the value type in `.env`:
- Never hardcode secrets in code - always use `settings` object

## Database Migrations (Alembic)

**Prerequisites:** Alembic commands require the database to be running. Before executing any Alembic commands. See section: [Checking if Application is Running](#Checking-if-Application-is-Running):
1. Check if the application is running
2. If not running, start it
3. Verify the database container is healthy

ALWAYS use Alembic for schema changes. Never modify database directly using following commands. BEFORE running the Alembic commands ALWAYS navigate to the backend and activate the venv by executing `cd backend && source .venv/bin/activate`:
```bash
alembic revision --autogenerate -m "Add column X to table Y"
```
if the revision was successfull, run the following command to apply all pending migrations:
```bash
alembic upgrade head
```

# Frontend Conventions/Rules:

## UI Design System
- **Use IBM Carbon Design System** for all UI components
- Import components from `@carbon/react`
- **Use Carbon Icons** for all icons - import from `@carbon/icons-react`
- Follow Carbon Design guidelines for consistency and accessibility
- **Theming:** Use the `ThemeProvider` from `@/components/theme/ThemeProvider` which wraps Carbon's `Theme` component and access theme state with `useTheme()` hook

**Note:** Refer to [Carbon Design System documentation](https://carbondesignsystem.com/) for component usage.

## Styling with Tailwind CSS

The project uses **Tailwind CSS** alongside Carbon Design System for utility-based styling:

### Carbon Design Tokens in Tailwind
- **Carbon tokens are mapped to Tailwind** via the `cds-*` prefix (defined in `frontend/src/styles/carbon-tw-mapping.ts`)
- Use `cds-*` classes for theme-aware colors that automatically adapt to light/dark mode

### Best Practices
- **ALWAYS** use Tailwind for styling
- **DON'T** use arbitrary color values like `text-red-500` for semantic colors - use `text-cds-support-error` instead
- **DO** use Tailwind for layout and spacing utilities
- **DO** combine Carbon components with Tailwind utility classes for layout
- **DON'T** override Carbon component styles unless absolutely necessary
- **DO** use `cds-*` color classes to ensure proper theme support

## File Structure

- **`frontend/src/routes/`** - File-based routing (TanStack Router)
- **`frontend/src/routes/_layout/`** - Protected routes (require auth)
- **`frontend/src/components/common/`** - Shared components
- **`frontend/src/components/[feature]/`** - Feature-specific components
- **`frontend/src/client/`** - Auto-generated API client (DO NOT EDIT!)

## Frontend Routing:
- Protected routes go under `_layout/`
- Use `createFileRoute` for route definition
- Export as `Route`
- `routeTree.gen.ts` is automatically created and updated and specifies the structure of the routes

## Data Fetching using TanStack Query
- Always use TanStack Query for all API calls
- Use auto-generated client from `@/client` 
- Invalidate queries after mutations

**IMPORTANT EXCEPTION:** For complex endpoints such as SSE, Websockets or other, you may use other technologies and not use the generated client or TanStack Query if they do not support the functionality correctly!

# Essential Workflows

## Adding a New Backend API Endpoint

**Prerequisites:** Ensure the application (especially the database) is running before steps 7-9.

1. Add model to `backend/app/tables.py`
2. Add schemas to `backend/app/models.py` (Create, Update, Public)
3. Add CRUD functions to `backend/app/crud.py`
4. Create route file in `backend/app/api/routes/`
5. Register router in `backend/app/api/main.py`
6. **Ensure that THIS app is running:** See section: [Checking if Application is Running](#Checking-if-Application-is-Running)
7. Create and apply the migration as mentioned in the section [Database Migrations (Alembic)](#Database-Migrations-(Alembic)): `cd backend && source .venv/bin/activate && alembic revision --autogenerate -m "message"`
8. Afterwards, apply that migration: `cd backend && source .venv/bin/activate && alembic upgrade head`
9. Regenerate client: `./scripts/generate-client.sh`. This updates `frontend/src/client/` - never edit these files manually.
10. If the user requests dummy data to be able to see the changes create an endpoint in the `backend/app/api/routes/utils.py` files that generates random items for the newly created tables. Be sure to use the `CurrentUser` dependency if the objects require a User ID, because otherwise the user will not be able to see the data, as the read operations filter objects for the current user. Lastly, request the user to execute

**IMPORTANT:** When defining SQLModel relationships in `tables.py`, use **string quotes** for forward references (classes defined later in the file). Example: If `TableA` references `TableB` which is defined below it, use `table_b: "TableB" = Relationship(...)`. Do NOT use `from __future__ import annotations` as it can cause issues with SQLAlchemy/SQLModel relationship resolution.

## Adding a New Frontend Page

1. Create file in `frontend/src/routes/_layout/pagename.tsx`
2. Use `createFileRoute` and export as `Route`
3. After adding a new page using Route, the `routeTree.gen.ts` file will be automatically updated after a certain amount of time
4. Add the new page to the header, so that the user doesn't need to type the URL in the browser

# Common Mistakes to Avoid
- **DON'T** mix SQLModel and Pydantic models - use SQLModel for `tables.py`, Pydantic for `models.py`
- **DON'T** modify database schema without Alembic migrations
- **DON'T** write database logic in route handlers - use `crud.py`
- **DON'T** manually edit `frontend/src/client/`, but regenerate the client which you also need to do after after any backend changes to the exposed routes by executing `./scripts/generate-client.sh` from the root directory
- **DON'T** forget to activate venv before running Alembic or executing any scripts
- **DON'T** run Alembic commands without ensuring the database is running first
- **DON'T** mix database models with API schemas!
- **DON'T** mix up other applications that are running with THIS one. Make sure to verify the prefix of the containers. See section: [Checking if Application is Running](#Checking-if-Application-is-Running)
- **DON'T** forget that the API endpoints have a prefix which is defined in the `API_V1_STR` under `backend/app/core/config.py`