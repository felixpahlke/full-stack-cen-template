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
            --dry-run=client -o yaml | apply_owned_oc_manifest
    fi
    [[ -n "$WEBHOOK_SECRET_VALUE" ]] || { print_error 'empty webhook secret'; return 1; }
}

record_component_webhook_url() {
    local component=$1 server url
    server=$(oc whoami --show-server)
    url="${server%/}/apis/build.openshift.io/v1/namespaces/${PROJECT_NAME}/buildconfigs/${component}/webhooks/${WEBHOOK_SECRET_VALUE}/github"
    add_deployment_output "${component}_webhook" "$url"
}

configure_component_webhook() {
    local component=$1 url code body curl_config payload_file response_file
    oc_resource_is_owned buildconfig "$component" || { warn_unowned_collision buildconfig "$component"; return 1; }
    record_component_webhook_url "$component"
    url=$(get_deployment_output "${component}_webhook")
    if ! make_github_curl_config curl_config; then
        print_warning "GITHUB_TOKEN is not set; GitHub push builds for $component are inactive. Set it and rerun deployment to enable them."
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

webhook_rolebinding_manifest() {
    cat <<EOF
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

check_webhook_rbac_permission() {
    local allowed
    if ! allowed=$(oc auth can-i create rolebindings.rbac.authorization.k8s.io --namespace "$PROJECT_NAME"); then
        print_error 'could not check permission to create the webhook RoleBinding'
        return 1
    fi
    if [[ "$allowed" == no ]]; then
        WEBHOOK_RBAC_DENIAL_REASON='current user cannot create RoleBindings in this project'
        return 2
    elif [[ "$allowed" != yes ]]; then
        print_error "unexpected response while checking permission to create the webhook RoleBinding: $allowed"
        return 1
    fi

    if ! allowed=$(oc auth can-i bind clusterroles.rbac.authorization.k8s.io/system:webhook --namespace "$PROJECT_NAME"); then
        print_error 'could not check permission to bind ClusterRole system:webhook'
        return 1
    fi
    if [[ "$allowed" == no ]]; then
        WEBHOOK_RBAC_DENIAL_REASON='current user cannot bind ClusterRole system:webhook in this project'
        return 2
    elif [[ "$allowed" != yes ]]; then
        print_error "unexpected response while checking permission to bind ClusterRole system:webhook: $allowed"
        return 1
    fi
}

webhook_rbac_apply_was_forbidden() {
    case "$1" in
        *'Error from server (Forbidden)'*|*'reason: Forbidden'*|*'is forbidden:'*|*'not permitted'*|*'cannot bind'*) return 0 ;;
        *) return 1 ;;
    esac
}

print_webhook_rbac_admin_instructions() {
    print_warning "Cannot configure OpenShift webhooks: $WEBHOOK_RBAC_DENIAL_REASON."
    printf '%s\n' \
        'GitHub webhooks are not active. Ask a cluster administrator to run:' \
        "oc -n $PROJECT_NAME apply -f - <<'EOF'" >&2
    webhook_rolebinding_manifest >&2
    printf '%s\n' \
        'EOF' \
        'Until this RoleBinding exists, GitHub pushes will not trigger OpenShift builds. Apply it and rerun deployment.' >&2
}

ensure_webhook_rbac() {
    local permission_status apply_output
    ensure_oc_resource_owned_or_absent rolebinding webhook-access-unauthenticated || return 1
    if ! resource_exists rolebinding webhook-access-unauthenticated; then
        if check_webhook_rbac_permission; then
            :
        else
            permission_status=$?
            [[ "$permission_status" == 2 ]] || return "$permission_status"
            print_webhook_rbac_admin_instructions
            return 2
        fi
    fi
    if apply_output=$(webhook_rolebinding_manifest | oc apply -f - 2>&1); then
        printf '%s\n' "$apply_output" >&2
    else
        printf '%s\n' "$apply_output" >&2
        if webhook_rbac_apply_was_forbidden "$apply_output"; then
            WEBHOOK_RBAC_DENIAL_REASON='OpenShift rejected the RoleBinding as forbidden'
            print_webhook_rbac_admin_instructions
            return 2
        fi
        return 1
    fi
}

setup_webhooks() {
    local automatic=true rbac_status
    ensure_webhook_secret
    if ensure_webhook_rbac; then
        :
    else
        rbac_status=$?
        [[ "$rbac_status" == 2 ]] || return "$rbac_status"
        add_deployment_output github_webhooks_configured false
        add_deployment_output github_webhooks_unavailable_reason "$WEBHOOK_RBAC_DENIAL_REASON"
        return 0
    fi
    git_repo_parts "$GIT_SSH_URL"
    [[ -n "${GITHUB_TOKEN:-}" ]] || automatic=false
    configure_component_webhook backend
    if [[ "$HAS_FRONTEND" == true ]]; then configure_component_webhook frontend; fi
    add_deployment_output github_webhooks_configured "$automatic"
}
