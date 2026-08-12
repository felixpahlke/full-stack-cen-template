#!/usr/bin/env bash

# Shared deployment primitives. Entry points set SCRIPT_DIR, PROJECT_ROOT, and ENV_FILE.

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly TEAL='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'
readonly CEN_MANAGED_BY_KEY='app.kubernetes.io/managed-by'
readonly CEN_MANAGED_BY_VALUE='cen-template'
readonly CEN_INSTANCE_KEY='app.kubernetes.io/instance'
readonly CEN_MANAGED_BY_LABEL="$CEN_MANAGED_BY_KEY=$CEN_MANAGED_BY_VALUE"

DEPLOY_DRY_RUN=false
DEPLOY_MOCK=false
DEPLOY_TMP_FILES=()
CONTAINER_CLI=

print_status() { printf '%b\n' "${TEAL}==>${NC} $1"; }
print_success() { printf '%b\n' "${GREEN}==>${NC} $1"; }
print_warning() { printf '%b\n' "${YELLOW}warning:${NC} $1" >&2; }
print_error() { printf '%b\n' "${RED}error:${NC} $1" >&2; }
print_section_header() { printf '\n%b\n' "${BLUE}== $1 ==${NC}"; }

has_interactive_terminal() {
    [[ "$DEPLOY_MOCK" == true && -n "${CEN_DEPLOY_TERMINAL_FILE:-}" ]] || [[ -t 0 && -t 1 ]]
}

print_terminal() {
    if [[ -n "${CEN_DEPLOY_TERMINAL_FILE:-}" && "$DEPLOY_MOCK" == true ]]; then
        printf '%s\n' "$1" >> "$CEN_DEPLOY_TERMINAL_FILE"
    elif [[ -w /dev/tty ]]; then
        printf '%s\n' "$1" > /dev/tty
    else
        return 1
    fi
}

add_deployment_output() { printf -v "DEPLOYMENT_OUTPUT__${1}" '%s' "$2"; }
get_deployment_output() { local key="DEPLOYMENT_OUTPUT__${1}"; printf '%s' "${!key-}"; }

print_deployment_summary() {
    local frontend_url backend_url oauth_proxy_url oauth_redirect_url backend_webhook frontend_webhook webhook_state webhook_reason
    frontend_url=$(get_deployment_output frontend_url)
    backend_url=$(get_deployment_output backend_url)
    oauth_proxy_url=$(get_deployment_output oauth_proxy_url)
    oauth_redirect_url=$(get_deployment_output oauth_redirect_url)
    backend_webhook=$(get_deployment_output backend_webhook)
    frontend_webhook=$(get_deployment_output frontend_webhook)
    webhook_state=$(get_deployment_output github_webhooks_configured)
    webhook_reason=$(get_deployment_output github_webhooks_unavailable_reason)
    print_success 'Deployment completed successfully.'
    [[ -z "$oauth_proxy_url" ]] || print_status "OAuth entry point: https://$oauth_proxy_url"
    [[ -z "$frontend_url" ]] || print_status "Frontend: https://$frontend_url"
    [[ -z "$backend_url" ]] || print_status "Backend: https://$backend_url"
    [[ -z "$oauth_redirect_url" ]] || print_status "OAuth redirect URL: $oauth_redirect_url"
    if [[ -n "$webhook_reason" ]]; then
        print_status "GitHub webhooks active: false ($webhook_reason)"
    elif [[ -n "$webhook_state" ]]; then
        print_status "GitHub webhooks configured automatically: $webhook_state"
    fi
    if [[ -n "$backend_webhook" || -n "$frontend_webhook" ]]; then
        print_terminal 'OpenShift webhook URLs (contain credentials; terminal-only):' || \
            print_warning 'Webhook URLs are hidden because no interactive terminal is available.'
        [[ -z "$frontend_webhook" ]] || print_terminal "  Frontend: $frontend_webhook" || true
        [[ -z "$backend_webhook" ]] || print_terminal "  Backend: $backend_webhook" || true
    fi
}

cen_ownership_labels() {
    printf '%s,%s=%s' "$CEN_MANAGED_BY_LABEL" "$CEN_INSTANCE_KEY" "${APP_NAME:?}"
}

resource_is_owned_by_this_deployment() {
    local managed=$1 instance=$2
    [[ "$managed" == "$CEN_MANAGED_BY_VALUE" && -n "${APP_NAME:-}" && "$instance" == "$APP_NAME" ]]
}

warn_unowned_collision() {
    printf 'WARNING: %s/%s exists but is not owned by this deployment (requires managed-by=cen-template and instance=%s); leaving it untouched\n' \
        "$1" "$2" "${APP_NAME:?}" >&2
}

cleanup_deploy_tmp_files() {
    if ((${#DEPLOY_TMP_FILES[@]})); then rm -f -- "${DEPLOY_TMP_FILES[@]}"; fi
}

make_temp_file() {
    local destination=$1 temp_file
    temp_file=$(mktemp "${TMPDIR:-/tmp}/cen-deploy.XXXXXX")
    chmod 600 "$temp_file"
    DEPLOY_TMP_FILES+=("$temp_file")
    printf -v "$destination" '%s' "$temp_file"
}

quote_command() {
    local argument
    printf '+'
    for argument in "$@"; do printf ' %q' "$argument"; done
    printf '\n'
}

run() {
    if [[ "$DEPLOY_DRY_RUN" == true ]]; then quote_command "$@"; else "$@"; fi
}

need_command() {
    command -v "$1" >/dev/null 2>&1 || {
        print_error "$1 is required but was not found in PATH"
        return 1
    }
}

select_container_cli() {
    [[ -z "$CONTAINER_CLI" ]] || return 0
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        CONTAINER_CLI=docker
    elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
        CONTAINER_CLI=podman
    else
        print_error 'a running Docker, Rancher Desktop, or Podman runtime is required'
        return 1
    fi
}

is_mock_command() {
    local command_name=$1 resolved mock_bin
    resolved=$(command -v "$command_name" 2>/dev/null || true)
    mock_bin=$(cd "${CEN_DEPLOY_MOCK_BIN:?}" && pwd -P)
    [[ -n "$resolved" && ! -L "$resolved" && -f "$resolved" \
        && "$(cd "$(dirname "$resolved")" && pwd -P)" == "$mock_bin" \
        && "$(sed -n '2p' "$resolved")" == '# cen-deploy-mock-command' ]]
}

validate_mock_commands() {
    [[ "$DEPLOY_MOCK" == true ]] || return 0
    local command_name
    for command_name in oc kubectl ibmcloud curl git; do
        is_mock_command "$command_name" || {
            print_error "mock deploy refused: $command_name is not a marked, non-symlink mock inside CEN_DEPLOY_MOCK_BIN"
            return 1
        }
    done
    if is_mock_command docker; then
        CONTAINER_CLI=docker
    elif is_mock_command podman; then
        CONTAINER_CLI=podman
    else
        print_error 'mock deploy refused: a marked docker or podman command is required'
        return 1
    fi
}

enable_mock_mode() {
    [[ "${CEN_DEPLOY_MOCK:-false}" == true ]] || return 0
    local mock_bin=${CEN_DEPLOY_MOCK_BIN:-} first_path
    [[ -n "$mock_bin" && -f "$mock_bin/.cen-deploy-mock-bin" ]] || {
        print_error 'CEN_DEPLOY_MOCK requires a marked CEN_DEPLOY_MOCK_BIN'
        return 1
    }
    mock_bin=$(cd "$mock_bin" && pwd -P)
    first_path=${PATH%%:*}
    first_path=$(cd "$first_path" && pwd -P)
    [[ "$first_path" == "$mock_bin" ]] || {
        print_error 'CEN_DEPLOY_MOCK_BIN must be the first PATH entry'
        return 1
    }
    DEPLOY_MOCK=true
    validate_mock_commands
}

strip_matching_quotes() {
    local value=$1 first last
    if ((${#value} >= 2)); then
        first=${value:0:1}; last=${value: -1}
        if [[ "$first" == "$last" && ( "$first" == '"' || "$first" == "'" ) ]]; then
            value=${value:1:${#value}-2}
        fi
    fi
    printf '%s' "$value"
}

is_deploy_control_env_name() {
    case "$1" in
        PATH|CDPATH|ENV|BASH_ENV|BASHOPTS|SHELLOPTS|IFS|GLOBIGNORE|\
        DEPLOY_*|CEN_DEPLOY_*|CEN_FLAVOR|APP_NAME|PROJECT_ROOT|SCRIPT_DIR|LIB_DIR|ENV_FILE|\
        OAUTH_ENABLED|HAS_FRONTEND|HAS_DATABASE|SHOW_*|RESET_*|REGENERATE_*|FLAVOR_OVERRIDE|\
        CE_SUBDOMAIN|CLUSTER_ID|BACKEND_URL|FRONTEND_URL|OAUTH_PROXY_URL|\
        CEN_MANAGED_BY_*|CEN_INSTANCE_*|DEPLOYMENT_OUTPUT_*|OPENSHIFT_SERVER)
            return 0 ;;
    esac
    return 1
}

load_branch_flavor() {
    local config="$SCRIPT_DIR/deploy-flavor.conf" line
    [[ -f "$config" ]] || { print_error "missing branch deployment identity: $config"; return 1; }
    line=$(sed -n 's/^CEN_DEPLOY_FLAVOR=//p' "$config")
    case "$line" in
        local-auth|local-auth-custom-ui) HAS_FRONTEND=true; HAS_DATABASE=true; OAUTH_ENABLED=false ;;
        oauth-proxy|oauth-proxy-custom-ui) HAS_FRONTEND=true; HAS_DATABASE=true; OAUTH_ENABLED=true ;;
        backend-only) HAS_FRONTEND=false; HAS_DATABASE=true; OAUTH_ENABLED=false ;;
        backend-only-no-db) HAS_FRONTEND=false; HAS_DATABASE=false; OAUTH_ENABLED=false ;;
        *) print_error "invalid branch deployment identity in $config"; return 1 ;;
    esac
    CEN_DEPLOY_FLAVOR=$line
    CEN_FLAVOR=$line
    DEPLOY_FRONTEND=$HAS_FRONTEND
    DEPLOY_DB=$HAS_DATABASE
    DEPLOY_BACKEND=true
    DEPLOY_OAUTH=$OAUTH_ENABLED
    export CEN_FLAVOR DEPLOY_FRONTEND DEPLOY_DB DEPLOY_BACKEND DEPLOY_OAUTH
}

load_env_file() {
    local env_file=$1 show_values=${2:-false} line name value clean_name
    [[ -f "$env_file" ]] || { print_error "environment file not found: $env_file"; return 1; }
    if [[ "$show_values" == true ]] && ! print_terminal "Environment values loaded from $env_file (explicitly requested):"; then
        print_error '--show-env-values requires an interactive terminal'
        return 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == export\ * ]] && line=${line#export }
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            name=${BASH_REMATCH[1]}
            value=$(strip_matching_quotes "${BASH_REMATCH[2]}")
            if is_deploy_control_env_name "$name"; then
                print_warning "ignoring deploy-control variable '$name' from $env_file"
                continue
            fi
            printf -v "$name" '%s' "$value"
            export -n "$name" 2>/dev/null || true
            if [[ "$name" == _* ]]; then
                clean_name=${name#_}
                [[ -z "$clean_name" ]] || { printf -v "$clean_name" '%s' "$value"; export -n "$clean_name" 2>/dev/null || true; }
            fi
            [[ "$show_values" != true ]] || print_terminal "  $name=$value"
        fi
    done < "$env_file"
    if [[ -n "${_CEN_FLAVOR:-}" && "$_CEN_FLAVOR" != "$CEN_DEPLOY_FLAVOR" ]]; then
        print_warning "ignoring _CEN_FLAVOR=$_CEN_FLAVOR; checked-out deployment identity is $CEN_DEPLOY_FLAVOR"
    fi
}

sanitize_name() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

resolve_app_name() {
    APP_NAME=$1
    if [[ -z "$APP_NAME" || ${#APP_NAME} -gt 63 || ! "$APP_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        print_error "invalid application identity: $1"
        return 1
    fi
}

validate_project_name() {
    local value=$1 limit=${2:-63} label=${3:-PROJECT_NAME}
    if [[ -z "$value" || ${#value} -gt "$limit" || ! "$value" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        print_error "$label must be a lowercase DNS label of at most $limit characters"
        return 1
    fi
}

validate_email() {
    [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || {
        print_error "FIRST_SUPERUSER is not a valid email address"
        return 1
    }
}

validate_api_key() {
    local length=${#1}
    case "$length" in
        16|32|64|128|256) ;;
        *) print_error "API_KEY length must be one of 16, 32, 64, 128, or 256 characters (current: $length)"; return 1 ;;
    esac
}

validate_password_minimum() {
    local value=$1 name=$2 minimum=${3:-8}
    ((${#value} >= minimum)) || {
        print_error "$name must be at least $minimum characters long (current: ${#value})"
        return 1
    }
}

is_placeholder_value() {
    case "$1" in
        changethis|replace-me|generate-on-first-dev-run|\<*\>|*placeholder*) return 0 ;;
    esac
    return 1
}

merge_cors_origin() {
    local configured=${1:-} generated=${2:-}
    [[ -n "$generated" ]] || { printf '%s' "$configured"; return 0; }
    node -e '
      const raw=process.argv[1].trim(), origin=process.argv[2]; let values=[];
      if(raw.startsWith("[")){try{values=JSON.parse(raw)}catch{process.exit(2)}}
      else if(raw) values=raw.split(",").map(x=>x.trim()).filter(Boolean);
      if(values.includes("*")){process.stdout.write("*");process.exit(0)}
      if(!values.includes(origin)) values.push(origin);
      process.stdout.write(values.join(","));' "$configured" "$generated" || {
        print_error 'BACKEND_CORS_ORIGINS must be a comma-separated list or a JSON array'
        return 1
    }
}

persist_env_value() {
    local name=$1 value=$2 persisted_file
    make_temp_file persisted_file
    awk -v key="$name" -v replacement="$name=$value" '
      BEGIN { written=0 }
      $0 ~ "^(# *)?" key "=" { if (!written) print replacement; written=1; next }
      { print }
      END { if (!written) print replacement }
    ' "$ENV_FILE" > "$persisted_file"
    chmod 600 "$persisted_file"
    mv "$persisted_file" "$ENV_FILE"
}

is_application_env_name() {
    local name=$1
    is_deploy_control_env_name "$name" && return 1
    case "$name" in
        _*|GITHUB_TOKEN|IAM_API_KEY|IBMCLOUD_API_KEY|TEST_DATABASE_URL|VITE_*|CEN_FLAVOR) return 1 ;;
        OAUTH2_PROXY_UPSTREAM_PASSWORD|OAUTH2_PROXY_WELL_KNOWN_URL) [[ "$OAUTH_ENABLED" == true ]] ; return ;;
        OAUTH2_PROXY_*) return 1 ;;
        POSTGRES_*|MIGRATE_ON_START) [[ "$HAS_DATABASE" == true ]] ; return ;;
    esac
    return 0
}

write_application_env_file() {
    local destination=$1 line name
    : > "$destination"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == export\ * ]] && line=${line#export }
        [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
        name=${BASH_REMATCH[1]}
        is_application_env_name "$name" || continue
        printf '%s=%s\n' "$name" "${!name-}" >> "$destination"
    done < "$ENV_FILE"
    printf 'CEN_FLAVOR=%s\n' "$CEN_DEPLOY_FLAVOR" >> "$destination"
}

write_oauth_env_file() {
    local destination=$1 public_url=$2 line name
    : > "$destination"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^(OAUTH2_PROXY_[A-Za-z0-9_]+)=(.*)$ ]] || continue
        name=${BASH_REMATCH[1]}
        case "$name" in
            OAUTH2_PROXY_UPSTREAM_PASSWORD|OAUTH2_PROXY_REDIRECT_URL|OAUTH2_PROXY_COOKIE_DOMAIN|\
            OAUTH2_PROXY_BASIC_AUTH_PASSWORD|OAUTH2_PROXY_COOKIE_SECURE) continue ;;
        esac
        printf '%s=%s\n' "$name" "${!name-}" >> "$destination"
    done < "$ENV_FILE"
    printf 'OAUTH2_PROXY_REDIRECT_URL=%s/oauth2/callback\n' "$public_url" >> "$destination"
    printf 'OAUTH2_PROXY_COOKIE_DOMAIN=%s\n' "${public_url#https://}" >> "$destination"
    printf 'OAUTH2_PROXY_BASIC_AUTH_PASSWORD=%s\n' "$OAUTH2_PROXY_UPSTREAM_PASSWORD" >> "$destination"
    printf 'OAUTH2_PROXY_COOKIE_SECURE=true\n' >> "$destination"
}

validate_runtime_env() {
    local missing=() key
    [[ -n "${PROJECT_NAME:-}" ]] || missing+=(PROJECT_NAME)
    [[ -n "${_APP_NAME:-}" ]] || missing+=(_APP_NAME)
    case "$CEN_DEPLOY_FLAVOR" in
        local-auth|local-auth-custom-ui)
            for key in FIRST_SUPERUSER FIRST_SUPERUSER_PASSWORD; do [[ -n "${!key:-}" ]] || missing+=("$key"); done
            ;;
        backend-only|backend-only-no-db)
            [[ -n "${API_KEY:-}" ]] || missing+=(API_KEY)
            ;;
    esac
    if [[ "$HAS_DATABASE" == true ]]; then
        for key in POSTGRES_SERVER POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD; do
            [[ -n "${!key:-}" ]] || missing+=("$key")
        done
    fi
    if [[ "$OAUTH_ENABLED" == true ]]; then
        for key in OAUTH2_PROXY_COOKIE_SECRET OAUTH2_PROXY_CLIENT_ID OAUTH2_PROXY_CLIENT_SECRET OAUTH2_PROXY_OIDC_ISSUER_URL; do
            [[ -n "${!key:-}" ]] || missing+=("$key")
        done
    fi
    if ((${#missing[@]})); then print_error "missing required environment values: ${missing[*]}"; return 1; fi

    validate_project_name "$PROJECT_NAME"
    if [[ -n "${_CE_PROJECT_NAME:-}" ]]; then validate_project_name "$_CE_PROJECT_NAME" 20 _CE_PROJECT_NAME; fi
    case "$CEN_DEPLOY_FLAVOR" in
        local-auth|local-auth-custom-ui)
            validate_email "$FIRST_SUPERUSER"
            validate_password_minimum "$FIRST_SUPERUSER_PASSWORD" FIRST_SUPERUSER_PASSWORD
            [[ -z "${SIGNUP_ACCESS_PASSWORD:-}" ]] || validate_password_minimum "$SIGNUP_ACCESS_PASSWORD" SIGNUP_ACCESS_PASSWORD
            if [[ -n "${SECRET_KEY:-}" ]] && ! is_placeholder_value "$SECRET_KEY"; then
                validate_password_minimum "$SECRET_KEY" SECRET_KEY 32
            fi
            ;;
        backend-only|backend-only-no-db) validate_api_key "$API_KEY" ;;
    esac
    if [[ "$HAS_DATABASE" == true ]]; then validate_password_minimum "$POSTGRES_PASSWORD" POSTGRES_PASSWORD; fi
    if [[ "$OAUTH_ENABLED" == true ]]; then
        validate_password_minimum "$OAUTH2_PROXY_COOKIE_SECRET" OAUTH2_PROXY_COOKIE_SECRET 32
        is_placeholder_value "$OAUTH2_PROXY_COOKIE_SECRET" && {
            print_error 'OAUTH2_PROXY_COOKIE_SECRET must not be a placeholder'
            return 1
        }
    fi
    return 0
}

confirm_target() {
    local label=$1 expected=$2 confirmation
    print_warning "Deployment may replace or delete only resources owned by $(cen_ownership_labels)."
    read -r -p "Continue with $label for '$expected'? [y/N]: " confirmation
    [[ "$confirmation" =~ ^[Yy]([Ee][Ss])?$ ]] || { print_error 'deployment cancelled'; return 1; }
}

show_help() {
    printf 'Usage: %s [--env-file PATH] [--reset-prod-db] [--regenerate-ssh-key] [--adopt-legacy-resources] [--show-env-values] [--dry-run]\n' "$0"
}
