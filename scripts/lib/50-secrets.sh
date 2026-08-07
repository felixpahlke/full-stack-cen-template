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
    local backend_host frontend_host oauth_host
    if [[ "$OAUTH_ENABLED" == true ]]; then
        oauth_host=$(oauth_public_host)
        FRONTEND_URL="https://$oauth_host"
        BACKEND_CORS_ORIGINS="https://$oauth_host"
        OAUTH2_PROXY_WELL_KNOWN_URL="${OAUTH2_PROXY_OIDC_ISSUER_URL%/}/.well-known/openid-configuration"
    else
        backend_host=$(capture_route_host backend)
        [[ -n "$backend_host" ]] || { print_error 'backend route host is unavailable'; return 1; }
        if [[ "$HAS_FRONTEND" == true ]]; then
            frontend_host=$(capture_route_host frontend)
            [[ -n "$frontend_host" ]] || { print_error 'frontend route host is unavailable'; return 1; }
            FRONTEND_URL="https://$frontend_host"
            BACKEND_CORS_ORIGINS="https://$frontend_host"
        else
            BACKEND_CORS_ORIGINS='*'
        fi
    fi
    create_backend_env_secret "$APP_NAME-env"
}

create_oauth_env_secret() {
    local public_url=$1 secret_file secret_name="$APP_NAME-oauth-proxy-secret"
    make_temp_file secret_file
    write_oauth_env_file "$secret_file" "$public_url"
    recreate_oc_env_secret "$secret_name" "$secret_file"
}
