---
name: prepare-workstation
description: Prepare a workstation for this container-free FastAPI development setup and its optional Docker/Podman, OpenShift, and Code Engine deployment tools.
---

# Prepare workstation

Audit first. Do not reinstall working tools, change system settings, use administrator access, or
install software without approval. On managed devices, follow company policy; never bypass
proxies, certificates, endpoint protection, or approved software catalogues.

## Audit

```bash
git --version
node --version
corepack --version
pnpm --version
python3 --version
uv --version
uv python find '>=3.10,<3.13'
docker --version
docker info
podman --version
podman info
oc version --client
ibmcloud --version
ibmcloud plugin show code-engine
ibmcloud plugin show container-registry
kubectl version --client
```

Node must satisfy `package.json` (20.19 or newer), pnpm must satisfy its `packageManager` field,
and uv must find a Python satisfying `backend/pyproject.toml` (3.10 through 3.12); the system
`python3` may differ. No container runtime is needed
for development or `pnpm run verify`. Docker Desktop, Rancher Desktop with dockerd/moby, native
Linux Docker, or Podman is needed only for image builds and Code Engine deployment; audit one when
that work is in scope. Compose is not used.

Use official platform installers for missing tools. The executable and IBM Cloud plugin names
above are canonical. Do not log in to OpenShift or IBM Cloud during workstation preparation.

Corepack is optional and may not be installed. If pnpm is missing, use an approved method from
the [official pnpm installation guide](https://pnpm.io/installation). When Corepack is available,
`corepack enable pnpm` can provision the pinned version. If it reports a signature error, update
Corepack with approval and
retry.

## Prepare this checkout

```bash
pnpm install
uv sync --project backend
uv run --project backend python --version
test -e .env || cp .env.example .env
```

Run `pnpm run dev` only when the application should start; it runs Uvicorn natively and starts no
containers. `DOCKER_HOST=unix:///nonexistent pnpm run verify` is the optional proof that normal
verification is container-free.
