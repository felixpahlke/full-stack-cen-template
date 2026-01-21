# OpenShift Deployment

Deploy your application to OpenShift using the automated deployment script.

## Quick Start

### 1. Prerequisites

- **OpenShift CLI** installed (`brew install openshift-cli`)
- **Git** installed

### 2. Create Environment File

```bash
cp .env.production.example .env.production
```

### 3. Configure Required Variables

Edit `.env.production` with your production values:

```bash
APP_NAME=my-app                              # Lowercase, hyphens only
PROJECT_NAME=my-openshift-project            # OpenShift namespace
GIT_SSH_URL=git@github.com:user/repo.git     # Repository SSH URL
# and so on...
```

> **❗️ Remember to change `changethis` values** ❗️

### 4. Create GitHub Token (Recommended)

This enables automatic deploy key and webhook setup:

**For IBM GitHub Enterprise:**

1. Go to https://github.ibm.com/settings/tokens

**For Public GitHub:**

1. Go to https://github.com/settings/tokens

**Then:** 2. Click "Generate new token (classic)" 3. Name it (e.g., "OpenShift Deployment") 4. Select scopes: `repo` and `admin:repo_hook` 5. Click "Generate token" and copy it 6. Add to `.env.production`: `GITHUB_TOKEN=ghp_your_token_here`

> **Note:** Without this token, you'll need to manually add deploy keys and webhooks after deployment.

### 5. Login to OpenShift

```bash
oc login --token=<token> --server=<server-url>
```

_Find this in the OpenShift console: top right corner → Copy login command_

### 6. Run Deployment

```bash
./scripts/oc-deploy.sh
```

The script guides you through the process and handles everything automatically.

> **💡 Good to know:**
>
> - The script is **idempotent** — you can rerun it anytime to update environment variables or configuration
> - Any **custom variables** you add to `.env.production` will be automatically passed to the backend as environment variables

---

## Deployment Flavors

Set `DEPLOYMENT_FLAVOR` in `.env.production`:

| Flavor                    | Components                      | Auth    | Use Case                        |
| ------------------------- | ------------------------------- | ------- | ------------------------------- |
| **oauth-proxy**           | Frontend + Backend + DB + OAuth | SSO     | Enterprise apps with SSO        |
| **oauth-proxy-custom-ui** | Backend + DB + OAuth            | SSO     | Custom frontend with SSO        |
| **local-auth**            | Frontend + Backend + DB         | Local   | Standard full-stack app         |
| **local-auth-custom-ui**  | Backend + DB                    | Local   | Custom frontend with local auth |
| **backend-only**          | Backend + DB                    | API Key | APIs for external frontends     |
| **backend-only-no-db**    | Backend only                    | API Key | Stateless APIs/microservices    |

---

## Command-Line Options

```bash
./scripts/oc-deploy.sh [options]

--flavor <name>         Override deployment flavor
--env-file <path>       Use custom environment file
--reset-prod-db         Reset database (WARNING: deletes data)
--regenerate-ssh-key    Regenerate SSH keys
--show-env-values       Show env values during deployment
--help                  Display help
```

---

## Common Issues

| Problem                   | Solution                                   |
| ------------------------- | ------------------------------------------ |
| `You must be logged in`   | Run `oc login --server=<url>`              |
| Deploy key already exists | Run with `--regenerate-ssh-key`            |
| Build failed              | Check logs: `oc logs -f bc/<app>-frontend` |
| Route not accessible      | Wait for builds: `oc get builds`           |

---

## More Information

For detailed configuration, architecture, extending the script, and advanced troubleshooting, see the [Script README](../scripts/README.md).
