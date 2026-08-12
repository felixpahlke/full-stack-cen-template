# Full Stack Client Engineering Template

A flexible starting point for full-stack web applications and APIs, from a complete React
application to a stateless FastAPI backend. Choose a flavour, create the project, and start
developing.

## Technology stack

- ⚡ [FastAPI](https://fastapi.tiangolo.com/) for the Python backend API.
  - [SQLModel](https://sqlmodel.tiangolo.com/) and [PostgreSQL](https://www.postgresql.org/) on
    database-backed flavours.
  - [Pydantic](https://docs.pydantic.dev/) for validation and settings.
  - [Alembic](https://alembic.sqlalchemy.org/) for migrations and
    [uv](https://docs.astral.sh/uv/) for Python dependencies.
- 🚀 [React 19](https://react.dev/) for full-stack flavours.
  - TypeScript, [Vite](https://vite.dev/), [TanStack Router](https://tanstack.com/router), and
    [TanStack Query](https://tanstack.com/query).
  - [IBM Carbon](https://carbondesignsystem.com/) or [shadcn/ui](https://ui.shadcn.com/), an
    automatically generated API client, and dark mode.
- 🧹 [Biome](https://biomejs.dev/) for JavaScript and TypeScript quality.
- 🛠️ Native development with automatic reload; containers run only the required backing services.
- 🔒 Local accounts, OAuth/OIDC, or API-key authentication depending on the flavour.
- 🚢 Deployment support for IBM Cloud Code Engine and OpenShift.

## Flavours

| Branch | Authentication | UI | Best fit |
| --- | --- | --- | --- |
| `oauth-proxy` | OAuth proxy with OIDC | Carbon | Production-oriented SSO application |
| `oauth-proxy-custom-ui` | OAuth proxy with OIDC | shadcn/ui | Adaptable SSO application |
| `local-auth` | Built-in email/password | Carbon | Self-contained application |
| `local-auth-custom-ui` | Built-in email/password | shadcn/ui | Adaptable self-contained application |
| `backend-only` | API key | None | PostgreSQL-backed API |
| `backend-only-no-db` | API key | None | Minimal stateless API |

Use a custom-UI flavour when Carbon is not the right fit. For full-stack applications, prefer an
OAuth-proxy flavour unless the application should own account and password security.

You are viewing the `local-auth-custom-ui` flavour: shadcn/ui with built-in email/password
authentication.

## Get started

Create a project and select the flavour interactively:

```bash
pnpm create cen-app@latest my-app
cd my-app
pnpm dev
```

The generator prepares the environment and dependencies. [pnpm](https://pnpm.io/installation) is
required; for manual setup or missing prerequisites, see the
[development guide](.docs/development.md).

## Sample applications and tutorials

- [Client Engineering DACH examples](https://github.ibm.com/client-engineering-dach/)
- [Full Stack CEN Template tutorials](https://github.ibm.com/client-engineering-dach/full-stack-cen-template-tutorials)

## AI-assisted development

[AGENTS.md](AGENTS.md) and the included project skills describe the repository conventions and
common workflows for compatible coding agents.

## Screenshots

### Dashboard

![Dashboard](.docs/img/dashboard-landing.png)

### Items

![Items](.docs/img/dashboard-items.png)

### Dark mode

![Dark mode](.docs/img/dark-mode.png)

### API documentation

![FastAPI documentation](.docs/img/docs.png)

## Documentation

- [Development, testing, commands, and troubleshooting](.docs/development.md)
- [Backend development and migrations](backend/README.md)
- [Frontend development and generated code](frontend/README.md)
- [Updating from the template](.agents/skills/update-from-template/SKILL.md)
- [Code Engine](.docs/ce-deployment.md) and [OpenShift](.docs/oc-deployment.md) deployment
- [Migration guide](.docs/migration-guide.md), [release notes](.docs/release-notes.md), and
  [changelog](CHANGELOG.md)

This template is based on
[full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template).
