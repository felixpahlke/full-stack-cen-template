# IBM Code Engine Deployment Guide

This guide covers deploying the application to **IBM Code Engine**, a serverless container platform with automatic scaling.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Configuration](#environment-configuration)
- [Frontend Configuration](#frontend-configuration)
- [Deployment](#deployment)
- [OAuth2 Proxy Configuration](#oauth2-proxy-configuration)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **IBM Cloud Account** with appropriate permissions
- **IBM Cloud CLI** installed
- **Container Registry Namespace** created
- **PostgreSQL Database** (provisioned manually)

### Install Required Tools

1. **IBM Cloud CLI**:

   ```bash
   curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
   ```

2. **Required Plugins**:

   ```bash
   ibmcloud plugin install container-registry
   ibmcloud plugin install code-engine
   ```

---

## Environment Configuration

### Step 1: Create Production Environment File

Copy the example file to create your production configuration:

```bash
cp .env.production.example .env.production
```

### Step 2: Configure Required Variables

Edit `.env.production` and set the required variables.

#### 1. General Configuration

```bash
# Application Identity
_APP_NAME=my-app
PROJECT_NAME=my-openshift-project
ENVIRONMENT=production

# Admin User
FIRST_SUPERUSER=admin@example.com
FIRST_SUPERUSER_PASSWORD=your-secure-password

# Backend Security
SECRET_KEY=your-secret-key-min-8-chars

# Database
POSTGRES_SERVER=your-db-host
POSTGRES_PORT=5432
POSTGRES_DB=app
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-db-password
```

#### 2. IBM Cloud Configuration

```bash
# IBM Cloud Authentication
_IBM_API_KEY=<your-api-key>
_IBM_CLOUD_URL=https://cloud.ibm.com

# IBM Cloud Resources
_IBM_CLOUD_RESOURCE_GROUP=Default
_IBM_CLOUD_REGION=eu-de
_IBM_CLOUD_ACCOUNT_NAME=Your Account Name

# Code Engine Project
_CE_PROJECT_NAME=my-project
_CR_REGISTRY=private.de.icr.io
```

### Understanding Variable Prefixes

You will notice some variables in `.env.production` are prefixed with an underscore (e.g., `_CE_PROJECT_NAME`).

- **Variables starting with `_`**: These are used **only by the deployment script** (e.g., to configure infrastructure) and are **NOT** passed to the application container.
- **Variables without `_`**: These are passed as environment variables to the running application.

> [!NOTE]
> This separation ensures that sensitive infrastructure credentials or script-specific configurations do not pollute the application's runtime environment.

---

## Frontend Configuration

### Nginx Configuration

The frontend use an Nginx server to serve the static files. For Code Engine deployments, the backend and frontend run as separate services (apps).

**Requirement:** You **MUST** disable the `/api` location block in `frontend/nginx.conf`.

1. Open `frontend/nginx.conf`.
2. Locate the `location /api` block.
3. Comment it out or remove it.

```nginx
# frontend/nginx.conf

# ... other config ...

# COMMENT THIS OUT FOR CODE ENGINE:
# location /api {
#   proxy_pass http://backend:8000;
# }
```

> [!IMPORTANT]
> If you leave this block active, Nginx will try to proxy requests to `http://backend:8000` inside the same container/pod, which **will fail** on Code Engine because the backend runs in a separate service. The deployment script has a check that will prevent deployment if this block is active.

---

## Deployment

### 1. Configure Secrets

Ensure all sensitive values in `.env.production` (like `SECRET_KEY`, `POSTGRES_PASSWORD`, `_IBM_API_KEY`) are set to your actual secret values.

> [!WARNING]
> Never commit `.env.production` to version control as it contains sensitive credentials.

### 2. Run Deployment Script

#### Standard Deployment

Deploys frontend and backend with public access (unless OAuth is configured).

```bash
./scripts/ce-deploy.sh
```

#### Deployment with OAuth2 Proxy

Deploys with OAuth2 Proxy sidecar for authentication/authorization.

```bash
./scripts/ce-deploy-oauth.sh
```

---

## OAuth2 Proxy Configuration

To protect your application with an OIDC provider (e.g., IBM App ID, Keycloak, Auth0), configure the following in `.env.production`:

```bash
# OAuth2 Proxy Cookie Secret (32 characters recommended)
OAUTH2_PROXY_COOKIE_SECRET=your-32-char-secret

# OIDC Provider Configuration
OAUTH2_PROXY_CLIENT_ID=your-client-id
OAUTH2_PROXY_CLIENT_SECRET=your-client-secret
OAUTH2_PROXY_OIDC_ISSUER_URL=https://your-oidc-provider.com

# Optional: Well-Known URL (Auto-generated if missing)
# Defaults to: ${OAUTH2_PROXY_OIDC_ISSUER_URL}/.well-known/openid-configuration
# OAUTH2_PROXY_WELL_KNOWN_URL=https://your-oidc-provider.com/.well-known/openid-configuration
```

**Behavior:**

- **All variables set:** OAuth2 Proxy is deployed and protects the application. Nginx and Backend are set to internal (cluster-local) access only.
- **Any variable missing:** OAuth2 Proxy is skipped. Application is publicly accessible.

---

## Post-Deployment

After a successful deployment, the script will output:

- **Application URLs** (Frontend, Backend, or OAuth Proxy)
- **Infrastructure Details** (Region, Project, Registry)

### Verifying Status

Check application status via CLI:

```bash
ibmcloud ce application list
```

View logs:

```bash
ibmcloud ce application logs --name <your-app-name>
```

---

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed

- **Symptoms:** Backend fails to start, logs show connection refused.
- **Fix:** Ensure `POSTGRES_SERVER` host is reachable from Code Engine. Check if your database allows connections from public IPs (if using public endpoints) or the correct private network. Code Engine does NOT run in your VPC by default; it connects via public internet unless specifically configured with Satellite or VPN.

#### 2. Frontend Cannot Reach Backend

- **Symptoms:** Frontend loads, but API calls fail (404 or Network Error).
- **Fix:**
  - Check browser console.
  - Verify `VITE_API_URL` was correctly updated in `.env.production` by the script.
  - Ensure `BACKEND_CORS_ORIGINS` includes the frontend URL.

#### 3. Deployment Script Fails on Nginx Check

- **Symptoms:** Script exits with "Found active 'location /api' block".
- **Fix:** Follow instructions in [Frontend Configuration](#frontend-configuration) to comment out the `/api` block.

#### 4. Build Failures

- **Symptoms:** `docker image build` fails.
- **Fix:**
  - Ensure Docker is running locally with `docker info`.
  - Check disk space.
  - If on Apple Silicon (M1/M2/M3), ensure you can build `linux/amd64` images (Deployment script forces this platform).

### Debugging

Enable verbose output for connection debugging by checking the `.env.production` values (the script updates them automatically):

```bash
cat .env.production | grep URL
```
