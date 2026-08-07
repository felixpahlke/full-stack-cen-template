#!/usr/bin/env bash

read_oc_secret_key() {
    local secret_name=$1 key=$2 encoded
    encoded=$(oc get secret "$secret_name" -o "jsonpath={.data.$key}" 2>/dev/null) || return 1
    [[ -n "$encoded" ]] || return 1
    if printf YQ== | base64 -d >/dev/null 2>&1; then printf '%s' "$encoded" | base64 -d
    else printf '%s' "$encoded" | base64 -D
    fi
}

recreate_oc_env_secret() {
    local secret_name=$1 env_file=$2
    ensure_oc_resource_owned_or_absent secret "$secret_name"
    if resource_exists secret "$secret_name"; then delete_owned_oc_resource secret "$secret_name"; fi
    oc create secret generic "$secret_name" --from-env-file="$env_file" \
        --labels "$(cen_ownership_labels)" --dry-run=client -o yaml | oc apply -f - >&2
}

ensure_local_auth_secret_key() {
    [[ "$CEN_DEPLOY_FLAVOR" == local-auth* ]] || return 0
    if [[ -n "${SECRET_KEY:-}" && "$SECRET_KEY" != changethis && ${#SECRET_KEY} -ge 32 ]]; then return 0; fi
    local secret_name="$APP_NAME-env" existing
    if resource_exists secret "$secret_name" && oc_resource_is_owned secret "$secret_name"; then
        existing=$(read_oc_secret_key "$secret_name" SECRET_KEY || true)
    fi
    if [[ -n "${existing:-}" && ${#existing} -ge 32 ]]; then SECRET_KEY=$existing
    else SECRET_KEY=$(openssl rand -hex 32) || return 1
    fi
    print_success 'Prepared a strong backend SECRET_KEY without printing it.'
}

create_backend_env_secret() {
    local secret_name=${1:-"$APP_NAME-env"} app_env
    ensure_local_auth_secret_key
    make_temp_file app_env
    write_application_env_file "$app_env"
    recreate_oc_env_secret "$secret_name" "$app_env"
}

create_initial_app_env_secret() { create_backend_env_secret "$APP_NAME-env"; }

update_app_env_secret_with_urls() {
    local backend_host frontend_host oauth_host generated_origin=''
    if [[ "$OAUTH_ENABLED" == true ]]; then
        oauth_host=$(oauth_public_host)
        FRONTEND_URL="https://$oauth_host"
        generated_origin="https://$oauth_host"
        OAUTH2_PROXY_WELL_KNOWN_URL="${OAUTH2_PROXY_OIDC_ISSUER_URL%/}/.well-known/openid-configuration"
    else
        backend_host=$(capture_route_host backend)
        [[ -n "$backend_host" ]] || { print_error 'backend route host is unavailable'; return 1; }
        if [[ "$HAS_FRONTEND" == true ]]; then
            frontend_host=$(capture_route_host frontend)
            [[ -n "$frontend_host" ]] || { print_error 'frontend route host is unavailable'; return 1; }
            FRONTEND_URL="https://$frontend_host"
            generated_origin="https://$frontend_host"
        fi
    fi
    BACKEND_CORS_ORIGINS=$(merge_cors_origin "${BACKEND_CORS_ORIGINS:-}" "$generated_origin") || return 1
    create_backend_env_secret "$APP_NAME-env"
}

create_oauth_env_secret() {
    local public_url=$1 secret_file secret_name="$APP_NAME-oauth-proxy-secret"
    if declare -F make_temp_file >/dev/null; then make_temp_file secret_file
    else secret_file=$(mktemp "${TMPDIR:-/tmp}/cen-oauth-secret.XXXXXX"); chmod 600 "$secret_file"
    fi
    if declare -F write_oauth_env_file >/dev/null; then write_oauth_env_file "$secret_file" "$public_url"
    else
        {
            printf 'OAUTH2_PROXY_COOKIE_SECRET=%s\n' "$OAUTH2_PROXY_COOKIE_SECRET"
            printf 'OAUTH2_PROXY_CLIENT_ID=%s\n' "$OAUTH2_PROXY_CLIENT_ID"
            printf 'OAUTH2_PROXY_CLIENT_SECRET=%s\n' "$OAUTH2_PROXY_CLIENT_SECRET"
            printf 'OAUTH2_PROXY_OIDC_ISSUER_URL=%s\n' "$OAUTH2_PROXY_OIDC_ISSUER_URL"
            printf 'OAUTH2_PROXY_REDIRECT_URL=%s/oauth2/callback\n' "$public_url"
            printf 'OAUTH2_PROXY_BASIC_AUTH_PASSWORD=%s\n' "$OAUTH2_PROXY_UPSTREAM_PASSWORD"
            printf 'OAUTH2_PROXY_COOKIE_SECURE=true\n'
        } > "$secret_file"
    fi
    if declare -F ensure_oc_resource_owned_or_absent >/dev/null; then recreate_oc_env_secret "$secret_name" "$secret_file"
    else oc create secret generic "$secret_name" --from-env-file="$secret_file"; rm -f "$secret_file"
    fi
}

# Compatibility helper retained for callers that source only the secret/OAuth libraries.
write_backend_secret_env_file() {
    local destination=$1 line name oauth_enabled=${OAUTH_ENABLED:-${DEPLOY_OAUTH:-false}} found=false
    : > "$destination"; chmod 600 "$destination"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
        name=${BASH_REMATCH[1]}
        [[ "$name" != _* && "$name" != VITE_* && "$name" != GITHUB_TOKEN && "$name" != IAM_API_KEY ]] || continue
        [[ "$name" != OAUTH2_PROXY_* || "$name" == OAUTH2_PROXY_UPSTREAM_PASSWORD || "$name" == OAUTH2_PROXY_WELL_KNOWN_URL ]] || continue
        printf '%s=%s\n' "$name" "${!name-}" >> "$destination"
        [[ "$name" != OAUTH2_PROXY_UPSTREAM_PASSWORD ]] || found=true
    done < "$ENV_FILE"
    if [[ "$oauth_enabled" == true && "$found" == false ]]; then
        printf 'OAUTH2_PROXY_UPSTREAM_PASSWORD=%s\n' "$OAUTH2_PROXY_UPSTREAM_PASSWORD" >> "$destination"
    fi
}
