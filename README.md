# Full Stack Client Engineering Template

## Technology Stack and Features

- ⚡ [**FastAPI**](https://fastapi.tiangolo.com) for the Python backend API.
  - 🧰 [SQLModel](https://sqlmodel.tiangolo.com) for database interactions on the flavours with relational persistence.
  - 🔍 [Pydantic](https://docs.pydantic.dev), used by FastAPI, for data validation and settings management.
  - 💾 [PostgreSQL](https://www.postgresql.org) on every database-backed flavour.
  - 📦 [uv](https://docs.astral.sh/uv/) for Python dependency management.
- 🚀 [React 19](https://react.dev) for the full-stack flavours' frontend.
  - 💃 TypeScript, [Vite](https://vite.dev), [TanStack Router](https://tanstack.com/router), and [TanStack Query](https://tanstack.com/query) form the modern frontend stack.
  - 🎨 [Carbon](https://carbondesignsystem.com/) or [shadcn/ui](https://ui.shadcn.com/), depending on the flavour, for frontend components.
  - 🤖 An automatically generated frontend client.
  - 🦇 Dark mode support.
- 🧹 [Biome](https://biomejs.dev/) for JavaScript and TypeScript linting and formatting.
- 🛠️ Native reload-enabled Uvicorn and Vite processes for development. [Docker Compose](https://www.docker.com) runs only the infrastructure a flavour needs: PostgreSQL and Adminer, plus Dex and oauth2-proxy on OAuth flavours. The stateless `backend-only-no-db` flavour needs no development containers.
- 🔒 Authentication via OAuth proxy with an IdP, in-app user management, or API key, depending on the flavour.
- 🚢 Deployment instructions for OpenShift and IBM Cloud Code Engine.

_This Template is based on [full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template)_

## Flavours

This template is available in different flavours, which are represented by different branches, make sure to pull the correct branch for your use case:

| Branch | Auth | UI | Pros | Cons |
| --- | --- | --- | --- | --- |
| `oauth-proxy` | OAuth proxy with IdP | Carbon | Production-oriented SSO boundary | Requires an OIDC provider in production |
| `oauth-proxy-custom-ui` | OAuth proxy with IdP | shadcn/ui | Adaptable UI with a production-oriented SSO boundary | Requires an OIDC provider in production |
| `local-auth` | In-app user management | Carbon | Self-contained and easy to start | The application owns password and account security |
| `local-auth-custom-ui` | In-app user management | shadcn/ui | Adaptable UI and easy local startup | The application owns password and account security |
| `backend-only` | API key | — | Focused API with PostgreSQL persistence | No bundled frontend |
| `backend-only-no-db` | API key | — | Minimal stateless API with Docker-free development | No bundled frontend or persistence |

<br />

> The custom-ui flavours are easily adaptable to look like any customers UI, so choose those if Carbon is not the right fit.

> For full-stack applications, prefer the `oauth-proxy` flavours, unless you have a specific reason not to use them.

## Flavour: `local-auth` — local authentication with Carbon

This branch provides a FastAPI/PostgreSQL backend, a React 19 frontend using IBM Carbon,
and built-in email/password authentication. Development runs the application processes
natively and uses Docker Compose only for PostgreSQL and Adminer. Production remains a
separate backend image and nginx frontend image.

### Quick start

Prerequisites: Node.js 20.19 or newer with Corepack and pnpm, Python 3.10–3.12, uv, and a running
container runtime. Supported choices are Docker Desktop, Rancher Desktop with the dockerd/moby
backend, native Linux Docker, and Podman. Docker requires the Compose plugin or standalone
`docker-compose`; Podman requires `podman compose` with a provider (`podman-compose` or standalone
`docker-compose`), or the `podman-compose` command. Start `podman machine` first where required.

Run this exact sequence from a fresh checkout:

```bash
corepack enable pnpm
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

Open the web app at `http://localhost:5173`, the API at `http://localhost:8000`, API docs
at `http://localhost:8000/docs`, and Adminer at `http://localhost:8080`. Log in with
`FIRST_SUPERUSER` and `FIRST_SUPERUSER_PASSWORD` from `.env`.

`pnpm run dev` starts PostgreSQL and Adminer in Compose, then runs reload-enabled Uvicorn
and Vite as native processes. It migrates the database and seeds the initial superuser
during backend startup. A backend source change also checks and regenerates the OpenAPI
client and route tree. Press Ctrl-C once for graceful shutdown; the supervisor forcibly
stops remaining children and Compose within about 12 seconds in the worst case. A second
Ctrl-C escalates immediately. The PostgreSQL volume is preserved.

### Root commands

| Command | Purpose |
| --- | --- |
| `pnpm run dev` | Start backing services plus native backend/frontend development processes |
| `pnpm run check` | Check generated files, types, JavaScript/CSS, and Python |
| `pnpm run fix` | Apply supported Biome and Ruff fixes |
| `pnpm run test` | Run supervisor, deployment-mock, and hermetic backend tests |
| `pnpm run build` | Build the production frontend bundle |
| `pnpm run verify` | Run `check`, `test`, and `build` |
| `pnpm run db:migrate` | Upgrade the configured database to the bundled Alembic head |
| `pnpm run db:revision -- -m "message"` | Generate a migration after model changes |
| `pnpm run test:deploy` | Run Code Engine and OpenShift deployment mocks |
| `pnpm run test:e2e` | Run Playwright; see the container pattern in the frontend guide |
| `pnpm run generate-client` | Regenerate OpenAPI, the TypeScript client, and route tree |

## Sample Applications & Tutorials

Check out our Collection of Sample Applications (AI-Chat, Agents, RAG, etc.) built on top of the template:

- [Client Engineering DACH 🚀](https://github.ibm.com/client-engineering-dach/)
- [Tutorials](https://github.ibm.com/client-engineering-dach/full-stack-cen-template-tutorials)

## AI-Assisted Development

This project includes an [AGENTS.md](./AGENTS.md) file that provides comprehensive guidelines for agentic AI assistants like [**Bob**](https://www.ibm.com/products/bob) to autonomously implement new features. The file contains:

- 📋 Project structure and conventions
- 🔧 Backend and frontend development rules
- 🚀 Essential workflows for common tasks
- ⚠️ Common mistakes to avoid

These guidelines enable AI assistants to understand the codebase and its conventions which leads to more robust and consistent code.

> **NOTE:** You can customize or delete the AGENTS.md file to influence the behavior of your coding assistant.

## Screenshots

The application screenshots show the full-stack frontend flavours; the backend-only flavours do not include a frontend.

### Dashboard

![API docs](.docs/img/dashboard-landing.png)

### Items

![API docs](.docs/img/dashboard-items.png)

### Dark Mode

![API docs](.docs/img/dark-mode.png)

### Interactive API Documentation

![API docs](.docs/img/docs.png)

## How to Use It

### Setup with [create-cen-app](https://github.com/felixpahlke/create-cen-app) and choose "full-stack-cen-template"

```bash
pnpm create cen-app@latest
```

### Or clone manually (commands may vary by flavour - check the specific branch):

- Clone this repository manually, set the name with the name of the project you want to use, for example `my-full-stack`:

```bash
git clone -b local-auth git@github.ibm.com:client-engineering-dach/full-stack-cen-template.git my-full-stack
```

- Enter into the new directory:

```bash
cd my-full-stack
```

- Set the new origin to your new repository (copy from GitHub interface):

```bash
git remote set-url origin git@github.ibm.com:my-username/my-full-stack.git
```

- Add the template repository as upstream to get future updates:

```bash
git remote add upstream git@github.ibm.com:client-engineering-dach/full-stack-cen-template.git
```

- Rename the branch if your new repository should use a different branch name:

```bash
git branch -m my-template-branch
```

- Push the code to your new repository:

```bash
git push -u origin my-template-branch
```

## Update From the Original Template

Follow [the update-from-template skill](./.agents/skills/update-from-template/SKILL.md) for the
upstream pull, conflict handling, regeneration, and verification before completing the merge.

## Development

General development docs: [development.md](./.docs/development.md).

Consumer migration guidance: [migration-guide.md](./.docs/migration-guide.md).

## Deployment

OpenShift Deployment docs: [oc-deployment.md](./.docs/oc-deployment.md).

Code Engine Deployment docs: [ce-deployment.md](./.docs/ce-deployment.md).

## Backend Development

Backend docs: [backend/README.md](./backend/README.md).

## Frontend Development

Frontend docs, including generated code and the Playwright container flow: [frontend/README.md](./frontend/README.md).

## Release Notes

Check the file [release-notes.md](./.docs/release-notes.md) and the [changelog](./CHANGELOG.md).
