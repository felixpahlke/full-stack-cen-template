# Full Stack Client Engineering Template

## Technology Stack and Features

- ⚡ [**FastAPI**](https://fastapi.tiangolo.com) for the Python backend API.
  - 🧰 [SQLModel](https://sqlmodel.tiangolo.com) for the Python SQL database interactions (ORM).
  - 🔍 [Pydantic](https://docs.pydantic.dev), used by FastAPI, for the data validation and settings management.
  - 💾 [PostgreSQL](https://www.postgresql.org) as the SQL database.
- 🚀 [React](https://react.dev) for the frontend.
  - 💃 Using TypeScript, hooks, Vite, and other parts of a modern frontend stack.
  - 🎨 [Carbon](https://carbondesignsystem.com/) & [Carboncn UI](https://www.carboncn.dev/) (optionally) for the frontend components.
  - 🤖 An automatically generated frontend client.
  - 🦇 Dark mode support.
- 🐋 [Docker Compose](https://www.docker.com) & [colima](https://github.com/abiosoft/colima/) for development.
- 🔒 Authentication via OAuth proxy with IdP (e.g. AppID) or in-app user management.
- 🚢 Deployment instructions using OpenShift.

_This Template is based on [full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template)_

## Flavours

This template is available in different flavours, which are represented by different branches, make sure to pull the correct branch for your use case:

| Branch                  | Auth                   | UI        | Pros             | Cons               |
| ----------------------- | ---------------------- | --------- | ---------------- | ------------------ |
| `oauth-proxy`           | OAuth proxy with IdP   | Carbon    | prod-friendly    | Needs AppID        |
| `oauth-proxy-custom-ui` | OAuth proxy with IdP   | shadcn/ui | prod-friendly    | Needs AppID        |
| `local-auth`            | In‑app user management | Carbon    | easy to start up | less prod-friendly |
| `local-auth-custom-ui`  | In‑app user management | shadcn/ui | easy to start up | less prod-friendly |
| `backend-only`          | API Key                | —         |
| `backend-only-no-db`    | API Key                | —         |

<br />

> The custom-ui flavours are easily adaptable to look like any customers UI, so choose those if Carbon is not the right fit.

> Prefer the `oauth-proxy` flavours, unless you have a specific reason to not use it.

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

### Dashboard

![API docs](.docs/img/dashboard-landing.png)

### Items

![API docs](.docs/img/dashboard-items.png)

### Dark Mode

![API docs](.docs/img/dark-mode.png)

### Interactive API Documentation

![API docs](.docs/img/docs.png)

### How to Use It

#### Setup with [create-cen-app](https://github.com/felixpahlke/create-cen-app) and choose "full-stack-cen-template"

```bash
npm create cen-app@latest
```

#### Or clone manually (commands may vary by flavour - check the specific branch):

- Clone this repository manually, set the name with the name of the project you want to use, for example `my-full-stack`:

```bash
git clone -b local-auth-custom-ui git@github.ibm.com:client-engineering-dach/full-stack-cen-template.git my-full-stack
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

### Update From the Original Template

After cloning the repository, and after doing changes, you might want to get the latest changes from this original template.

- Make sure you added the original repository as a remote, you can check it with:

```bash
git remote -v

origin    git@github.ibm.com:my-username/my-full-stack.git (fetch)
origin    git@github.ibm.com:my-username/my-full-stack.git (push)
upstream    git@github.ibm.com:client-engineering-dach/full-stack-cen-template.git (fetch)
upstream    git@github.ibm.com:client-engineering-dach/full-stack-cen-template.git (push)
```

- Pull the latest changes without merging (commands may vary by flavour - check the specific branch):

```bash
git pull --no-commit upstream local-auth-custom-ui
```

This will download the latest changes from this template without committing them, that way you can check everything is right before committing.

- If there are conflicts, solve them in your editor.

- Once you are done, commit the changes:

```bash
git merge --continue
```

## Development

### Quick start

Prerequisites are Node.js 20.19+, npm, Python 3.10–3.12, uv, and a running Docker
runtime with Docker Compose. Bootstrap a fresh checkout with these four commands:

```bash
cp .env.example .env
npm ci
npm --prefix frontend ci
uv sync --project backend
```

Then start the development stack:

```bash
npm run dev
```

This starts PostgreSQL 12 and Adminer in Compose, applies migrations, seeds the
initial superuser, and runs reload-enabled Uvicorn and strict-port Vite natively.
Backend API changes regenerate the frontend client automatically. See
[development.md](./.docs/development.md) for ports, logs, tests, and troubleshooting.

## Deployment

OpenShift Deployment docs: [oc-deployment.md](./.docs/oc-deployment.md).

Code Engine Deployment docs: [ce-deployment.md](./.docs/ce-deployment.md).

## Backend Development

Backend docs: [backend/README.md](./backend/README.md).

## Frontend Development

Frontend docs: [frontend/README.md](./frontend/README.md).

## Release Notes

Check the file [release-notes.md](./.docs/release-notes.md).
