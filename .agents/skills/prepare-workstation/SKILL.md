---
name: prepare-workstation
description: Prepare a workstation for this pnpm, uv, PostgreSQL, and deployment toolchain by auditing prerequisites and installing only what is missing.
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
docker compose version
docker info
podman --version
podman compose version
podman info
oc version --client
ibmcloud --version
ibmcloud plugin show code-engine
ibmcloud plugin show container-registry
kubectl version --client
```

Node must satisfy `package.json` (20.19 or newer), pnpm must satisfy its `packageManager` field,
and uv must find a Python satisfying `backend/pyproject.toml` (3.10 through 3.12); the system
`python3` may differ. Only one supported container
runtime must work: Docker Desktop, Rancher Desktop with dockerd/moby, Colima, native Linux Docker,
or Podman with an available Compose provider. Podman Desktop's Docker compatibility socket is
supported even when it presents through the `docker` CLI and the `default` context. A CLI-only
install is insufficient: its `info` and Compose checks must succeed.

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

Before starting, confirm another checkout is not using the configured ports; stop only that
checkout's supervisor and verify its prefixed containers are gone. Run `pnpm run dev` only when the
application should start. It launches PostgreSQL and Adminer via
the detected Compose provider and runs Uvicorn and Vite natively. Stop it with Ctrl-C and confirm
only this checkout's containers were removed.
