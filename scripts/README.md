# OpenShift Deployment Script

Automated deployment script for deploying full-stack applications to OpenShift with PostgreSQL database, OAuth2 authentication, and GitHub webhook integration.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage](#usage)
- [Features](#features)
- [Deployment Phases](#deployment-phases)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [Architecture](#architecture)

## Quick Start

1. **Copy the environment template:**

   ```bash
   cp scripts/.env.production.example scripts/.env.production
   ```

2. **Configure required variables** in `scripts/.env.production`:

   ```bash
   APP_NAME=my-app
   PROJECT_NAME=my-openshift-project
   GIT_SSH_URL=git@github.com:username/repository.git
   FIRST_SUPERUSER=admin@example.com
   FIRST_SUPERUSER_PASSWORD=your-secure-password
   SECRET_KEY=your-secret-key
   POSTGRES_PASSWORD=your-db-password
   ```

3. **Login to OpenShift:**

   ```bash
   oc login --server=https://your-openshift-cluster:6443
   ```

4. **Run the deployment:**
   ```bash
   ./scripts/oc-deploy.sh
   ```

## Prerequisites

### Required Tools

- **OpenShift CLI (`oc`)** - Version 4.x or higher

  ```bash
  # Check version
  oc version
  ```

- **Git** - For repository access
  ```bash
  git --version
  ```

### OpenShift Access

- Active OpenShift cluster login
- Permissions to create projects, deployments, services, routes, and secrets
- Sufficient resource quotas for your application

### GitHub Access (Optional but Recommended)

- **GitHub Personal Access Token** with `repo` and `admin:repo_hook` permissions
- Required for automatic deploy key and webhook setup
- Without token: Manual setup required (see [Manual GitHub Setup](#manual-github-setup))

## Configuration

### Environment File Structure

The deployment script uses `scripts/.env.production` for all configuration. See [`scripts/.env.production.example`](scripts/.env.production.example) for a complete template with detailed comments.

### Deployment Modes & Required Variables

The script supports different deployment modes which require different sets of variables.

#### 1. Full Stack (Default)

Requires all standard variables: `APP_NAME`, `PROJECT_NAME`, `GIT_SSH_URL`, `FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD`, `SECRET_KEY`, plus all `POSTGRES_*` variables.

#### 2. Backend Only (`--backend-only`)

Skips frontend deployment.

- **Removes Requirement:** `FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD`, `SIGNUP_ACCESS_PASSWORD`, `SECRET_KEY`
- **Adds Requirement:** `API_KEY` (Must be set in `.env.production`)

#### 3. No Database (`--no-db`)

Skips PostgreSQL deployment.

- **Removes Requirement:** All `POSTGRES_*` variables (`POSTGRES_SERVER`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`)

### Required Variables Reference

| Variable                   | Description            | Validation                                   |
| -------------------------- | ---------------------- | -------------------------------------------- |
| `APP_NAME`                 | Application name       | Lowercase, alphanumeric, hyphens only        |
| `PROJECT_NAME`             | OpenShift project name | Lowercase, alphanumeric, hyphens only        |
| `GIT_SSH_URL`              | Git repository SSH URL | Format: `git@github.com:user/repo.git`       |
| `FIRST_SUPERUSER`          | Admin email            | Valid email format (Full Stack only)         |
| `FIRST_SUPERUSER_PASSWORD` | Admin password         | Minimum 8 characters (Full Stack only)       |
| `API_KEY`                  | API security key       | 16, 32, or 64 characters (Backend Only only) |
| `SECRET_KEY`               | Backend secret key     | Minimum 8 characters (Full Stack only)       |
| `POSTGRES_PASSWORD`        | Database password      | Minimum 8 characters (If DB enabled)         |

### Optional Variables

#### GitHub Integration

```bash
# GitHub host (default: github.ibm.com)
GITHUB_HOST=github.ibm.com  # or github.com for public GitHub

# Personal Access Token for automation
GITHUB_TOKEN=ghp_your_token_here
```

**Creating a GitHub Token:**

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select scopes: `repo`, `admin:repo_hook`
4. Copy and paste into `.env.production`

#### OAuth2 Proxy (Optional)

Enable OAuth2 authentication by configuring all OAuth variables:

```bash
OAUTH2_PROXY_COOKIE_DOMAIN=your-app.example.com
OAUTH2_PROXY_COOKIE_SECRET=32-char-random-string
OAUTH2_PROXY_CLIENT_ID=your-client-id
OAUTH2_PROXY_CLIENT_SECRET=your-client-secret
OAUTH2_PROXY_OIDC_ISSUER_URL=https://your-oidc-provider.com
OAUTH2_PROXY_REDIRECT_URL=https://your-app.example.com/oauth2/callback
```

#### Frontend Environment Variables

All variables prefixed with `VITE_` are automatically injected into the frontend build:

```bash
VITE_CUSTOM_FEATURE=enabled
VITE_ANALYTICS_ID=UA-123456-1
VITE_APP_VERSION=1.0.0
```

#### Webhook Branch Filter

Trigger builds only for specific branches:

```bash
WEBHOOK_BRANCH_FILTER=main  # Only build on main branch updates
```

## Usage

### Basic Deployment

```bash
./scripts/oc-deploy.sh
```

### Command-Line Options

```bash
# Use custom environment file
./scripts/oc-deploy.sh --env-file /path/to/.env

# Reset production database (WARNING: Deletes all data)
./scripts/oc-deploy.sh --reset-prod-db

# Regenerate SSH keys
./scripts/oc-deploy.sh --regenerate-ssh-key

# Show environment values during deployment (for debugging)
./scripts/oc-deploy.sh --show-env-values

# Deploy only the backend (skips frontend)
./scripts/oc-deploy.sh --backend-only

# Skip database deployment
./scripts/oc-deploy.sh --no-db

# Display help
./scripts/oc-deploy.sh --help
```

### Combining Options

```bash
# Backend-only deployment without database
./scripts/oc-deploy.sh --backend-only --no-db

# Reset database and regenerate SSH keys
./scripts/oc-deploy.sh --reset-prod-db --regenerate-ssh-key
```

## Features

### ✅ Idempotent Operations

- Safe to run multiple times
- Updates existing resources instead of failing
- No side effects from repeated executions

### ✅ Comprehensive Validation

- All required variables validated before deployment
- Format validation (emails, URLs, names)
- Clear error messages for invalid configurations

### ✅ Automatic Secret Management

- Dynamic secret creation from environment variables
- Automatic injection of generated URLs
- Sensitive values masked in output

### ✅ SSH Key Management

- Automatic SSH key pair generation
- GitHub deploy key verification and creation
- Key regeneration on demand

### ✅ Database Management

- PostgreSQL deployment with persistent storage
- Database reset functionality
- Automatic connection configuration

### ✅ GitHub Webhook Automation

- Automatic webhook creation for frontend and backend
- Branch filtering support
- Manual fallback instructions if token not provided

### ✅ OAuth2 Proxy Support

- Optional OAuth2 authentication layer
- Automatic configuration and deployment
- Seamless integration with backend

### ✅ Clean Output

- Color-coded status messages
- Library context prefixes for clarity
- Deployment summary at completion

### ✅ Flexible Deployment Modes

- **Full Stack:** Deploys Frontend, Backend, and Database (Default)
- **Backend Only:** Deploys only Backend and Database (Use `--backend-only` or `DEPLOY_BACKEND_ONLY=true`)
- **No Database:** Deploys application without managing a PostgreSQL instance (Use `--no-db` or `DEPLOY_DB=false`)
- **Backend Only + No DB:** Deploys only the Backend service (Great for lightweight APIs)

## Deployment Phases

The script executes in 7 distinct phases:

### Phase 1: Initialization

- Load environment variables from `.env.production`
- Validate all required variables
- Check variable formats and constraints

### Phase 2: Prerequisites Check

- Verify OpenShift CLI version
- Confirm OpenShift login status
- Check cluster connectivity

### Phase 3: Project Setup

- Create or verify OpenShift project
- Setup SSH keys for Git access
- Add deploy key to GitHub (if token provided)

### Phase 4: Database Deployment

- Create application secrets
- Deploy PostgreSQL database
- Configure persistent storage

### Phase 5: Application Deployment

- Deploy frontend application
- Deploy backend application
- Update secrets with generated URLs
- Deploy OAuth2 Proxy (if configured)

### Phase 6: Configuration

- Configure frontend environment
- Configure backend environment
- Group application resources
- Setup resource labels

### Phase 7: Post-Deployment

- Setup GitHub webhooks (if token provided)
- Display deployment summary
- Show application URLs

## Troubleshooting

### Common Issues

#### 1. OpenShift Login Failed

**Error:** `You must be logged in to the server`

**Solution:**

```bash
oc login --server=https://your-openshift-cluster:6443
```

#### 2. SSH Key Already Exists on GitHub

**Error:** `Deploy key already exists on GitHub`

**Solution:**

```bash
# Regenerate SSH keys
./scripts/oc-deploy.sh --regenerate-ssh-key
```

#### 3. Database Connection Failed

**Error:** `Failed to connect to database`

**Solution:**

- Check database pod status: `oc get pods`
- View database logs: `oc logs <postgres-pod-name>`
- Verify database password in secrets

#### 4. Build Failed

**Error:** `Build failed` or `ImagePullBackOff`

**Solution:**

- Check build logs: `oc logs -f bc/<app-name>-frontend`
- Verify Git repository access
- Check SSH key configuration

#### 5. Route Not Accessible

**Error:** Application URL returns 404 or connection refused

**Solution:**

- Wait for builds to complete: `oc get builds`
- Check pod status: `oc get pods`
- Verify route: `oc get routes`
- Check pod logs: `oc logs <pod-name>`

### Debug Mode

Enable verbose output to see environment values:

```bash
./scripts/oc-deploy.sh --show-env-values
```

### Manual Verification

```bash
# Check all resources
oc get all

# Check secrets
oc get secrets

# Check routes
oc get routes

# Check builds
oc get builds

# View pod logs
oc logs -f <pod-name>
```

## Advanced Usage

### Manual GitHub Setup

If you don't have a GitHub token, manually configure:

1. **Add Deploy Key:**

   - Get public key: `oc get secret git-ssh-key -o jsonpath='{.data.ssh-publickey}' | base64 -d`
   - Go to GitHub repository → Settings → Deploy keys
   - Add new deploy key with read access

2. **Add Webhooks:**
   - Get webhook URLs from deployment summary
   - Go to GitHub repository → Settings → Webhooks
   - Add webhook with URL and secret from OpenShift

### Database Reset

**⚠️ WARNING:** This deletes all production data!

```bash
./scripts/oc-deploy.sh --reset-prod-db
```

This will:

1. Delete the PostgreSQL deployment
2. Delete the persistent volume claim
3. Redeploy a fresh database
4. Run initial data migrations

### Custom Environment File

Use a different environment file:

```bash
./scripts/oc-deploy.sh --env-file /path/to/custom.env
```

### Extending the Script

The script uses a modular library structure in `scripts/lib/`:

| Library             | Purpose                | Key Functions                                                          |
| ------------------- | ---------------------- | ---------------------------------------------------------------------- |
| `00-common.sh`      | Core utilities         | `print_status()`, `print_success()`, `print_error()`                   |
| `10-validation.sh`  | Input validation       | `validate_name()`, `validate_email()`, `validate_git_url()`            |
| `20-environment.sh` | Environment management | `load_env_file()`, `validate_required_vars()`                          |
| `30-openshift.sh`   | OpenShift operations   | `setup_project()`, `resource_exists()`, `apply_resource()`             |
| `40-ssh.sh`         | SSH key management     | `setup_ssh_keys()`, `add_github_deploy_key()`                          |
| `50-secrets.sh`     | Secret management      | `create_initial_app_env_secret()`, `update_app_env_secret_with_urls()` |
| `60-database.sh`    | Database operations    | `deploy_database()`, `reset_production_database()`                     |
| `70-deployment.sh`  | Application deployment | `deploy_frontend()`, `deploy_backend()`, `configure_frontend()`        |
| `75-oauth.sh`       | OAuth2 Proxy           | `deploy_oauth_proxy()`, `create_oauth_proxy_route()`                   |
| `80-webhooks.sh`    | Webhook management     | `setup_webhooks()`, `create_github_webhook()`                          |

#### Adding Custom Functionality

1. Create a new library file in `scripts/lib/` (e.g., `85-custom.sh`)
2. Follow the naming convention: `NN-name.sh` where NN determines load order
3. Use the print functions with library context:
   ```bash
   print_status "Doing something..." "custom"
   print_success "Done!" "custom"
   ```
4. Return error codes (0=success, 1=failure) instead of using `exit`
5. Add deployment info to summary:
   ```bash
   add_deployment_output "custom_url" "https://custom.example.com"
   ```

## Architecture

### Modular Design

The script follows a modular architecture with clear separation of concerns:

```
scripts/
├── oc-deploy.sh              # Main orchestration script (215 lines)
├── .env.production           # Configuration file
├── .env.production.example   # Configuration template
└── lib/                      # Modular libraries
    ├── 00-common.sh          # Utilities & output
    ├── 10-validation.sh      # Input validation
    ├── 20-environment.sh     # Environment management
    ├── 30-openshift.sh       # OpenShift operations
    ├── 40-ssh.sh             # SSH key management
    ├── 50-secrets.sh         # Secret management
    ├── 60-database.sh        # Database operations
    ├── 70-deployment.sh      # Application deployment
    ├── 75-oauth.sh           # OAuth2 Proxy
    └── 80-webhooks.sh        # Webhook automation
```

### Benefits

- **88% smaller main script** (1514 → 215 lines)
- **Maintainable** - Easy to find and update code
- **Testable** - Each library can be tested independently
- **Extensible** - Add new features without modifying core logic
- **Professional** - Follows shell scripting best practices

### Output System

The script uses a structured print system with:

- **Color-coded messages** (status, success, error, warning)
- **Library context prefixes** (e.g., `[openshift]`, `[database]`)
- **Phase headers** for clear progress tracking
- **Deployment summary** with all important URLs and information

See [`PRINT_SYSTEM.md`](PRINT_SYSTEM.md) for detailed documentation.

## Best Practices

### Security

- ✅ Never commit `.env.production` to version control
- ✅ Use strong passwords (minimum 8 characters)
- ✅ Rotate API keys and secrets regularly
- ✅ Use GitHub tokens with minimal required permissions
- ✅ Review OpenShift RBAC permissions

### Deployment

- ✅ Test in development environment first
- ✅ Review deployment summary after each run
- ✅ Monitor build logs for errors
- ✅ Verify application functionality after deployment
- ✅ Keep `.env.production.example` updated with new variables

### Maintenance

- ✅ Document custom environment variables
- ✅ Keep OpenShift CLI updated
- ✅ Review and update resource quotas as needed
- ✅ Backup database before using `--reset-prod-db`
- ✅ Test webhook functionality after setup

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review OpenShift logs: `oc logs <pod-name>`
3. Verify configuration in `.env.production`
4. Check OpenShift cluster status and quotas

## License

This deployment script is part of the full-stack application template created with [create-cen-app](https://github.com/felixpahlke/create-cen-app).
