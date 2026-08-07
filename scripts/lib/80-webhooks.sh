#!/usr/bin/env bash

ensure_webhook_secret() {
    local secret_name=github-webhook-secret secret_file
    if resource_exists secret "$secret_name"; then
        ensure_oc_resource_owned_or_absent secret "$secret_name"
        WEBHOOK_SECRET_VALUE=$(read_oc_secret_key "$secret_name" WebHookSecretKey) || {
            print_error "$secret_name is missing WebHookSecretKey"
            return 1
        }
    else
        WEBHOOK_SECRET_VALUE=$(openssl rand -hex 24) || return 1
        make_temp_file secret_file
        printf '%s' "$WEBHOOK_SECRET_VALUE" > "$secret_file"
        oc create secret generic "$secret_name" --from-file="WebHookSecretKey=$secret_file" \
            --labels "$(cen_ownership_labels)" --dry-run=client -o yaml | oc apply -f - >&2
    fi
    [[ -n "$WEBHOOK_SECRET_VALUE" ]] || { print_error 'empty webhook secret'; return 1; }
}

configure_component_webhook() {
    local component=$1 server url redacted_url response code body curl_config payload_file
    oc_resource_is_owned buildconfig "$component" || { warn_unowned_collision buildconfig "$component"; return 1; }
    server=$(oc whoami --show-server)
    url="${server%/}/apis/build.openshift.io/v1/namespaces/${PROJECT_NAME}/buildconfigs/${component}/webhooks/${WEBHOOK_SECRET_VALUE}/github"
    redacted_url="${server%/}/apis/build.openshift.io/v1/namespaces/${PROJECT_NAME}/buildconfigs/${component}/webhooks/<redacted-webhook-secret>/github"
    if ! make_github_curl_config curl_config; then
        print_warning "Configure the $component webhook manually: $redacted_url"
        return 0
    fi
    response=$(curl --disable --config "$curl_config" --silent --show-error --write-out '\n%{http_code}' --url "$GITHUB_REPO_API/hooks" || true)
    code=$(printf '%s\n' "$response" | tail -n 1); body=$(printf '%s\n' "$response" | sed '$d')
    if [[ "$code" =~ ^2 && "$body" == *"$url"* ]]; then return 0; fi
    make_temp_file payload_file
    printf '{"name":"web","active":true,"events":["push"],"config":{"url":"%s","content_type":"json","insecure_ssl":"0"}}' "$url" > "$payload_file"
    response=$(curl --disable --config "$curl_config" --silent --show-error --write-out '\n%{http_code}' \
        --request POST --header 'Accept: application/vnd.github+json' --url "$GITHUB_REPO_API/hooks" \
        --data-binary "@$payload_file" || true)
    code=$(printf '%s\n' "$response" | tail -n 1)
    [[ "$code" =~ ^2 ]] || print_warning "GitHub webhook creation failed (HTTP $code); use: $redacted_url"
}

setup_webhooks() {
    ensure_webhook_secret
    git_repo_parts "$GIT_SSH_URL"
    configure_component_webhook backend
    if [[ "$HAS_FRONTEND" == true ]]; then configure_component_webhook frontend; fi
    add_deployment_output github_webhooks_configured true
}
