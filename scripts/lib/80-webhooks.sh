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
    local component=$1 server url code body curl_config payload_file response_file
    oc_resource_is_owned buildconfig "$component" || { warn_unowned_collision buildconfig "$component"; return 1; }
    server=$(oc whoami --show-server)
    url="${server%/}/apis/build.openshift.io/v1/namespaces/${PROJECT_NAME}/buildconfigs/${component}/webhooks/${WEBHOOK_SECRET_VALUE}/github"
    add_deployment_output "${component}_webhook" "$url"
    if ! make_github_curl_config curl_config; then
        print_warning "GITHUB_TOKEN is not set; configure the $component GitHub webhook manually."
        print_terminal "Manual $component webhook URL: $url" || \
            print_warning 'The credential-bearing URL is hidden because no interactive terminal is available.'
        return 0
    fi
    make_temp_file response_file
    if ! code=$(curl --disable --config "$curl_config" --silent --show-error --output "$response_file" \
        --write-out '%{http_code}' --url "$GITHUB_REPO_API/hooks"); then
        print_error "GitHub webhook lookup failed for $component"
        return 1
    fi
    body=$(<"$response_file")
    if [[ "$code" =~ ^2 && "$body" == *"$url"* ]]; then return 0; fi
    [[ "$code" =~ ^2 ]] || { print_error "GitHub webhook lookup failed for $component (HTTP $code)"; return 1; }
    make_temp_file payload_file
    printf '{"name":"web","active":true,"events":["push"],"config":{"url":"%s","content_type":"json","insecure_ssl":"0"}}' "$url" > "$payload_file"
    if ! code=$(curl --disable --config "$curl_config" --silent --show-error --output "$response_file" --write-out '%{http_code}' \
        --request POST --header 'Accept: application/vnd.github+json' --url "$GITHUB_REPO_API/hooks" \
        --data-binary "@$payload_file"); then
        print_error "GitHub webhook creation request failed for $component"
        return 1
    fi
    [[ "$code" =~ ^2 ]] || { print_error "GitHub webhook creation failed for $component (HTTP $code)"; return 1; }
    print_success "GitHub webhook configured for $component."
}

ensure_webhook_rbac() {
    ensure_oc_resource_owned_or_absent rolebinding webhook-access-unauthenticated
    cat <<EOF | apply_resource 'unauthenticated OpenShift build webhook access'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: webhook-access-unauthenticated
  labels: {$CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
  annotations: {rbac.authorization.kubernetes.io/autoupdate: "true"}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: system:webhook}
subjects: [{apiGroup: rbac.authorization.k8s.io, kind: Group, name: system:unauthenticated}]
EOF
}

setup_webhooks() {
    local automatic=true
    ensure_webhook_secret
    ensure_webhook_rbac
    git_repo_parts "$GIT_SSH_URL"
    [[ -n "${GITHUB_TOKEN:-}" ]] || automatic=false
    configure_component_webhook backend
    if [[ "$HAS_FRONTEND" == true ]]; then configure_component_webhook frontend; fi
    add_deployment_output github_webhooks_configured "$automatic"
}
