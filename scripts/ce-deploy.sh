#!/usr/bin/env bash
set -euo pipefail
set +x

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/00-common.sh
source "$SCRIPT_DIR/lib/00-common.sh"
trap cleanup_deploy_tmp_files EXIT

ENV_FILE="$PROJECT_ROOT/.env.production"
SHOW_ENV_VALUES=false
OAUTH2_PROXY_IMAGE='quay.io/oauth2-proxy/oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561'

parse_arguments() {
    while (($#)); do
        case "$1" in
            -h|--help) printf 'Usage: %s [--env-file PATH] [--show-env-values] [--dry-run]\n' "$0"; exit 0 ;;
            --env-file) ENV_FILE=${2:?}; shift 2 ;;
            --show-env-values) SHOW_ENV_VALUES=true; shift ;;
            --dry-run) DEPLOY_DRY_RUN=true; shift ;;
            *) print_error "unknown option: $1"; exit 2 ;;
        esac
    done
}

ce_resource_exists() { kubectl get "$1" "$2" >/dev/null 2>&1; }

ce_resource_is_owned() {
    local kind=$1 name=$2 managed instance
    managed=$(kubectl get "$kind" "$name" -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
    instance=$(kubectl get "$kind" "$name" -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null || true)
    resource_is_owned_by_this_deployment "$managed" "$instance"
}

ensure_ce_resource_owned_or_absent() {
    local kind=$1 name=$2 display=${3:-$1}
    if ce_resource_exists "$kind" "$name" && ! ce_resource_is_owned "$kind" "$name"; then
        warn_unowned_collision "$display" "$name"
        return 1
    fi
}

label_ce_resource() {
    run kubectl label "$1" "$2" "$CEN_MANAGED_BY_LABEL" "$CEN_INSTANCE_KEY=$APP_NAME" --overwrite
}

delete_owned_ce_resource() {
    local kind=$1 name=$2 display=${3:-$1}
    ce_resource_exists "$kind" "$name" || { print_status "$display/$name is absent; nothing to delete"; return 0; }
    if ! ce_resource_is_owned "$kind" "$name"; then warn_unowned_collision "$display" "$name"; return 0; fi
    print_warning "Deleting owned $display/$name"
    case "$kind" in
        services.serving.knative.dev) run ibmcloud ce application delete --name "$name" --force ;;
        secret) run ibmcloud ce secret delete --name "$name" --force >&2 ;;
    esac
}

check_code_engine_preconditions() {
    need_command ibmcloud; need_command kubectl; need_command docker
    if ! ibmcloud plugin show container-registry >/dev/null 2>&1; then run ibmcloud plugin install -f container-registry; fi
    if ! ibmcloud plugin show code-engine >/dev/null 2>&1; then run ibmcloud plugin install -f code-engine; fi
    ibmcloud account show >/dev/null 2>&1 || { print_error "log in with 'ibmcloud login --sso'"; return 1; }
    if [[ -n "${_IBM_CLOUD_ACCOUNT_NAME:-}" ]]; then
        local current_account
        current_account=$(ibmcloud account show | awk -F': ' '/Account Name:/ {print $2; exit}')
        [[ -z "$current_account" || "$current_account" == "$_IBM_CLOUD_ACCOUNT_NAME" ]] || {
            print_error "IBM Cloud account mismatch: '$current_account' != '$_IBM_CLOUD_ACCOUNT_NAME'"
            return 1
        }
    fi
}

target_code_engine_project() {
    run ibmcloud target -g "$_IBM_CLOUD_RESOURCE_GROUP"
    run ibmcloud target -r "$_IBM_CLOUD_REGION"
    if ibmcloud ce project get --name "$_CE_PROJECT_NAME" >/dev/null 2>&1; then
        run ibmcloud ce project select --name "$_CE_PROJECT_NAME" --kubecfg
    else
        if [[ "$OAUTH_ENABLED" == true ]]; then
            print_error "OAuth deployment requires an existing readable Code Engine project '$_CE_PROJECT_NAME' so visibility narrowing can be the first cloud mutation"
            return 1
        fi
        run ibmcloud ce project create --name "$_CE_PROJECT_NAME"
        run ibmcloud ce project select --name "$_CE_PROJECT_NAME" --kubecfg
    fi
    CE_SUBDOMAIN=$(ibmcloud ce project current | awk '/Subdomain:/ {print $2; exit}')
    [[ -n "$CE_SUBDOMAIN" ]] || { print_error 'could not read Code Engine project subdomain'; return 1; }
    CLUSTER_ID=${CE_SUBDOMAIN#*.}
    CLUSTER_ID=${CLUSTER_ID%%.*}
}

visibility_not_found() {
    local output=$1 name=$2
    printf '%s\n' "$output" | grep -Eiq "(application ['\"]?${name}['\"]? (was )?not found|application ['\"]?${name}['\"]? does not exist|resource_not_found)"
}

reconcile_one_oauth_visibility() {
    local name=$1 inspection output command_status
    set +e
    inspection=$(kubectl get services.serving.knative.dev "$name" -o name 2>&1)
    command_status=$?
    set -e
    if ((command_status == 0)); then
        ce_resource_is_owned services.serving.knative.dev "$name" || { warn_unowned_collision application "$name"; return 1; }
    elif ! printf '%s\n' "$inspection" | grep -Eiq '(notfound|not found)'; then
        print_error "could not inspect ownership of application/$name before visibility mutation"
        [[ -z "$inspection" ]] || printf '%s\n' "$inspection" >&2
        return 1
    fi
    print_status "Failing closed: attempting project visibility for application/$name before registry, build, secret, or cleanup mutations."
    set +e
    output=$(ibmcloud ce application update --name "$name" --visibility project 2>&1)
    command_status=$?
    set -e
    ((command_status == 0)) && return 0
    visibility_not_found "$output" "$name" && { print_status "application/$name is confirmed absent"; return 0; }
    print_error "could not prove application/$name absent or make it project-only"
    [[ -z "$output" ]] || printf '%s\n' "$output" >&2
    return 1
}

reconcile_oauth_visibility() {
    [[ "$OAUTH_ENABLED" == true ]] || return 0
    reconcile_one_oauth_visibility "$_CE_BACKEND_APPLICATION_NAME"
    reconcile_one_oauth_visibility "$_CE_FRONTEND_APPLICATION_NAME"
}

preflight_ce_collisions() {
    ensure_ce_resource_owned_or_absent services.serving.knative.dev "$_CE_BACKEND_APPLICATION_NAME" application
    ensure_ce_resource_owned_or_absent secret "$_CE_BACKEND_ENV_SECRET_NAME"
    if [[ "$HAS_FRONTEND" == true ]]; then
        ensure_ce_resource_owned_or_absent services.serving.knative.dev "$_CE_FRONTEND_APPLICATION_NAME" application
    fi
    if [[ "$OAUTH_ENABLED" == true ]]; then
        ensure_ce_resource_owned_or_absent services.serving.knative.dev oauth-proxy application
        ensure_ce_resource_owned_or_absent secret oauth-proxy-secret
    fi
    if ce_resource_exists secret "$_CR_REGISTRY_SECRET_NAME"; then
        ce_resource_is_owned secret "$_CR_REGISTRY_SECRET_NAME" || { warn_unowned_collision registry-secret "$_CR_REGISTRY_SECRET_NAME"; return 1; }
    fi
}

target_registry() {
    run ibmcloud cr login
    if ! ibmcloud cr namespace-list | awk '{for(i=1;i<=NF;i++)print $i}' | grep -Fxq "$_CR_NAMESPACE"; then
        run ibmcloud cr namespace-add "$_CR_NAMESPACE"
    fi
}

ensure_registry_secret() {
    local key_file
    if ibmcloud ce registry get --name "$_CR_REGISTRY_SECRET_NAME" >/dev/null 2>&1; then
        if ! ce_resource_exists secret "$_CR_REGISTRY_SECRET_NAME" || ! ce_resource_is_owned secret "$_CR_REGISTRY_SECRET_NAME"; then
            warn_unowned_collision registry-secret "$_CR_REGISTRY_SECRET_NAME"
            return 1
        fi
        print_warning "Deleting owned registry-secret/$_CR_REGISTRY_SECRET_NAME before exact recreation"
        ibmcloud ce registry delete --name "$_CR_REGISTRY_SECRET_NAME" --force >&2
    elif ce_resource_exists secret "$_CR_REGISTRY_SECRET_NAME"; then
        warn_unowned_collision secret "$_CR_REGISTRY_SECRET_NAME"
        return 1
    fi
    [[ -n "${_IAM_API_KEY:-}" ]] || { print_error '_IAM_API_KEY is required for the Code Engine registry secret'; return 1; }
    make_temp_file key_file
    printf '%s' "$_IAM_API_KEY" > "$key_file"
    ibmcloud ce registry create --name "$_CR_REGISTRY_SECRET_NAME" --server "$_CR_REGISTRY" \
        --username iamapikey --password-from-file "$key_file" >&2
    label_ce_resource secret "$_CR_REGISTRY_SECRET_NAME"
}

sync_ce_env_secret() {
    local name=$1 env_file=$2
    ensure_ce_resource_owned_or_absent secret "$name"
    if ce_resource_exists secret "$name"; then delete_owned_ce_resource secret "$name"; fi
    ibmcloud ce secret create --name "$name" --from-env-file "$env_file" >&2
    label_ce_resource secret "$name"
}

ensure_backend_secret() {
    local backend_env
    make_temp_file backend_env
    write_application_env_file "$backend_env"
    sync_ce_env_secret "$_CE_BACKEND_ENV_SECRET_NAME" "$backend_env"
}

build_and_push_images() {
    local backend_image="$_CR_REGISTRY/$_CR_NAMESPACE/$_CE_BACKEND_IMAGE_NAME:latest"
    run docker image build --platform linux/amd64 -t "$backend_image" --load "$PROJECT_ROOT/backend"
    run docker image push "$backend_image"
    if [[ "$HAS_FRONTEND" == true ]]; then
        local frontend_image="$_CR_REGISTRY/$_CR_NAMESPACE/$_CE_FRONTEND_IMAGE_NAME:latest" line name value
        local build_args=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^(VITE_[A-Za-z0-9_]+)=(.*)$ ]] || continue
            name=${BASH_REMATCH[1]}; value=${!name-}
            [[ "$name" != VITE_API_URL ]] || value=$BACKEND_URL
            build_args+=("--build-arg=$name=$value")
        done < "$ENV_FILE"
        run docker image build --platform linux/amd64 -t "$frontend_image" "${build_args[@]}" \
            --build-arg "NODE_ENV=${NODE_ENV:-production}" --load "$PROJECT_ROOT/frontend"
        run docker image push "$frontend_image"
    fi
}

ensure_ce_application() {
    local name=$1 image=$2 port=$3 secret_name=${4:-} visibility=public action=create
    [[ "$OAUTH_ENABLED" != true ]] || visibility=project
    if ce_resource_exists services.serving.knative.dev "$name"; then
        ce_resource_is_owned services.serving.knative.dev "$name" || { warn_unowned_collision application "$name"; return 1; }
        action=update
    fi
    local arguments=(application "$action" --name "$name" --image "$image" --registry-secret "$_CR_REGISTRY_SECRET_NAME" \
        --port "http1:$port" --visibility "$visibility" --min-scale 1 --max-scale 4 --scale-down-delay 600)
    [[ -z "$secret_name" ]] || arguments+=(--env-from-secret "$secret_name")
    if [[ "$name" == "$_CE_BACKEND_APPLICATION_NAME" ]]; then
        arguments+=(--cpu 1 --memory 4G --ephemeral-storage 1.5G \
            --probe-live type=http --probe-live path=/api/v1/utils/health-check/ --probe-live port=8000 \
            --probe-ready type=http --probe-ready path=/api/v1/utils/health-check/ --probe-ready port=8000)
    else
        arguments+=(--cpu 0.5 --memory 1G --probe-live type=http --probe-live path=/healthz --probe-live port=8080 \
            --probe-ready type=http --probe-ready path=/healthz --probe-ready port=8080)
    fi
    run ibmcloud ce "${arguments[@]}"
    label_ce_resource services.serving.knative.dev "$name"
}

ce_application_url() {
    local output
    output=$(ibmcloud ce application get --name "$1" --output url 2>/dev/null || true)
    printf '%s\n' "$output" | grep -Eo 'https?://[^[:space:]]+' | head -n1 | sed 's/,$//' || true
}

ensure_oauth_proxy() {
    [[ "$OAUTH_ENABLED" == true ]] || return 0
    local name=oauth-proxy public_url oauth_env action=create
    public_url=$(ce_application_url "$name")
    [[ -n "$public_url" ]] || public_url="https://oauth-proxy.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
    make_temp_file oauth_env
    write_oauth_env_file "$oauth_env" "$public_url"
    sync_ce_env_secret oauth-proxy-secret "$oauth_env"
    if ce_resource_exists services.serving.knative.dev "$name"; then
        ce_resource_is_owned services.serving.knative.dev "$name" || { warn_unowned_collision application "$name"; return 1; }
        action=update
    fi
    local args=(application "$action" --name "$name" --image "$OAUTH2_PROXY_IMAGE" --port http1:4180 \
        --env-from-secret oauth-proxy-secret --visibility public --min-scale 1 --max-scale 2 --cpu 0.25 --memory 0.5G \
        --argument=--provider=oidc --argument=--email-domain=* --argument=--http-address=:4180 \
        --argument=--pass-basic-auth=true --argument=--pass-user-headers=true \
        --argument=--pass-authorization-header=false --argument=--set-authorization-header=false \
        --argument=--skip-auth-strip-headers=true --argument=--cookie-secure=true \
        --argument=--cookie-httponly=true --argument=--cookie-samesite=lax \
        --argument=--insecure-oidc-allow-unverified-email=true --argument=--pass-host-header=false \
        --argument=--skip-provider-button=true --argument=--upstream-timeout=300s \
        "--argument=--upstream=http://$_CE_FRONTEND_APPLICATION_NAME.$CE_SUBDOMAIN.svc.cluster.local/" \
        "--argument=--upstream=http://$_CE_BACKEND_APPLICATION_NAME.$CE_SUBDOMAIN.svc.cluster.local/api/" \
        "--argument=--upstream=http://$_CE_BACKEND_APPLICATION_NAME.$CE_SUBDOMAIN.svc.cluster.local/static/")
    run ibmcloud ce "${args[@]}"
    label_ce_resource services.serving.knative.dev "$name"
    add_deployment_output oauth_proxy_url "${public_url#https://}"
}

reconcile_obsolete_ce_resources() {
    if [[ "$HAS_FRONTEND" != true ]]; then delete_owned_ce_resource services.serving.knative.dev "$_CE_FRONTEND_APPLICATION_NAME" application; fi
    if [[ "$OAUTH_ENABLED" != true ]]; then
        delete_owned_ce_resource services.serving.knative.dev oauth-proxy application
        delete_owned_ce_resource secret oauth-proxy-secret
    fi
}

set_deployment_urls() {
    if [[ "$OAUTH_ENABLED" == true ]]; then
        OAUTH_PROXY_URL="https://oauth-proxy.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
        BACKEND_URL=$OAUTH_PROXY_URL; FRONTEND_URL=$OAUTH_PROXY_URL
    else
        BACKEND_URL="https://${_CE_BACKEND_APPLICATION_NAME}.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
        FRONTEND_URL="https://${_CE_FRONTEND_APPLICATION_NAME}.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
    fi
    if [[ "$HAS_FRONTEND" == true ]]; then BACKEND_CORS_ORIGINS=$FRONTEND_URL; else BACKEND_CORS_ORIGINS='*'; fi
    if [[ "$OAUTH_ENABLED" == true ]]; then OAUTH2_PROXY_WELL_KNOWN_URL="${OAUTH2_PROXY_OIDC_ISSUER_URL%/}/.well-known/openid-configuration"; fi
}

dry_run_plan() {
    print_status "Branch deployment identity: $CEN_DEPLOY_FLAVOR"
    if [[ "$HAS_FRONTEND" == true ]]; then print_status 'Images: backend + nginx frontend'; else print_status 'Images: backend only'; fi
    print_status "Ownership: $(cen_ownership_labels)"
    [[ "$OAUTH_ENABLED" != true ]] || quote_command ibmcloud ce application update --name "$_CE_BACKEND_APPLICATION_NAME" --visibility project
}

main() {
    parse_arguments "$@"
    load_branch_flavor
    enable_mock_mode
    load_env_file "$ENV_FILE" "$SHOW_ENV_VALUES"
    validate_mock_commands
    resolve_app_name "${_APP_NAME:-${_CE_PROJECT_NAME:-cen-app}}"
    validate_runtime_env
    : "${_IBM_CLOUD_RESOURCE_GROUP:?}" "${_IBM_CLOUD_REGION:?}" "${_CE_PROJECT_NAME:?}" "${_CR_REGISTRY:?}"
    _CE_FRONTEND_IMAGE_NAME=${_CE_FRONTEND_IMAGE_NAME:-frontend}
    _CE_FRONTEND_APPLICATION_NAME=${_CE_FRONTEND_APPLICATION_NAME:-"${_CE_PROJECT_NAME}-frontend"}
    _CE_BACKEND_IMAGE_NAME=${_CE_BACKEND_IMAGE_NAME:-backend}
    _CE_BACKEND_ENV_SECRET_NAME=${_CE_BACKEND_ENV_SECRET_NAME:-"${_CE_PROJECT_NAME}-backend-config"}
    _CE_BACKEND_APPLICATION_NAME=${_CE_BACKEND_APPLICATION_NAME:-"${_CE_PROJECT_NAME}-backend"}
    _CR_REGISTRY_SECRET_NAME=${_CR_REGISTRY_SECRET_NAME:-"${_CE_PROJECT_NAME}-registry-secret"}
    _CR_NAMESPACE=${_CR_NAMESPACE:-"${_CE_PROJECT_NAME}-namespace"}

    print_section_header 'Code Engine deployment'
    if [[ "$DEPLOY_DRY_RUN" == true ]]; then dry_run_plan; return 0; fi
    check_code_engine_preconditions
    confirm_target 'Code Engine deployment' "$_CE_PROJECT_NAME"
    target_code_engine_project
    reconcile_oauth_visibility
    preflight_ce_collisions
    set_deployment_urls
    if [[ "$HAS_DATABASE" == true && "$POSTGRES_SERVER" == postgresql ]]; then
        print_error 'Code Engine requires an external POSTGRES_SERVER'
        return 1
    fi
    target_registry
    ensure_registry_secret
    build_and_push_images
    ensure_backend_secret
    ensure_ce_application "$_CE_BACKEND_APPLICATION_NAME" "$_CR_REGISTRY/$_CR_NAMESPACE/$_CE_BACKEND_IMAGE_NAME:latest" 8000 "$_CE_BACKEND_ENV_SECRET_NAME"
    if [[ "$HAS_FRONTEND" == true ]]; then
        ensure_ce_application "$_CE_FRONTEND_APPLICATION_NAME" "$_CR_REGISTRY/$_CR_NAMESPACE/$_CE_FRONTEND_IMAGE_NAME:latest" 8080
    fi
    ensure_oauth_proxy
    reconcile_obsolete_ce_resources
    print_deployment_summary
}

main "$@"
