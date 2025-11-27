# OpenShift Deployment Libraries

This directory contains modular libraries for the OpenShift deployment script.

## Libraries (Load Order)

| File | Purpose | Lines |
|------|---------|-------|
| `00-common.sh` | Core utilities, print functions, output collection | 223 |
| `10-validation.sh` | Input validation functions | 99 |
| `20-environment.sh` | Environment variable management | 195 |
| `30-openshift.sh` | OpenShift CLI operations | 122 |
| `40-ssh.sh` | SSH key and GitHub deploy key management | 260 |
| `50-secrets.sh` | Kubernetes secret management | 145 |
| `60-database.sh` | PostgreSQL deployment and operations | 203 |
| `70-deployment.sh` | Frontend/backend deployment | 211 |
| `75-oauth.sh` | OAuth2 Proxy deployment (optional) | 283 |
| `80-webhooks.sh` | GitHub webhook automation | 181 |

**Total**: ~1,922 lines (modular) vs 1,514 lines (monolithic)

## Usage

Libraries are automatically sourced by the main script in numerical order:

```bash
for lib_file in "$LIB_DIR"/*.sh; do
    source "$lib_file"
done
```

## Design Principles

1. **Single Responsibility**: Each library handles one aspect of deployment
2. **Return Codes**: Functions return 0 (success) or 1 (failure), never call `exit`
3. **Output Collection**: User-facing info is added to `DEPLOYMENT_OUTPUT` array
4. **Error Messages**: Use `print_error()`, `print_warning()`, `print_status()`, `print_success()`
5. **No Side Effects**: Functions are idempotent where possible

## Adding New Functions

1. Choose the appropriate library based on responsibility
2. Follow the error handling pattern (return codes, not exit)
3. Add user-facing output to `DEPLOYMENT_OUTPUT` if needed
4. Document the function with comments
5. Test thoroughly

## Dependencies

- Libraries are loaded in order (00 → 80)
- Later libraries can use functions from earlier ones
- No circular dependencies