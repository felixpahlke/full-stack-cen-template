#!/usr/bin/env bash

resource_exists() { oc get "$1" "$2" >/dev/null 2>&1; }

oc_resource_is_owned() {
    local kind=$1 name=$2 managed instance
    managed=$(oc get "$kind" "$name" -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
    instance=$(oc get "$kind" "$name" -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null || true)
    resource_is_owned_by_this_deployment "$managed" "$instance"
}

ensure_oc_resource_owned_or_absent() {
    local kind=$1 name=$2
    if resource_exists "$kind" "$name" && ! oc_resource_is_owned "$kind" "$name"; then
        warn_unowned_collision "$kind" "$name"
        return 1
    fi
}

delete_owned_oc_resource() {
    local kind=$1 name=$2
    resource_exists "$kind" "$name" || { print_status "$kind/$name is absent; nothing to delete"; return 0; }
    if ! oc_resource_is_owned "$kind" "$name"; then warn_unowned_collision "$kind" "$name"; return 0; fi
    print_warning "Deleting owned $kind/$name"
    run oc delete "$kind/$name" --ignore-not-found
}

apply_resource() {
    local description=${1:-generated}
    if [[ "$DEPLOY_DRY_RUN" == true ]]; then print_status "Would apply $description resources"; return 0; fi
    oc apply -f - >&2
}

apply_owned_oc_manifest() {
    oc label --local -f - "$CEN_MANAGED_BY_LABEL" "$CEN_INSTANCE_KEY=$APP_NAME" -o yaml \
        | oc apply -f - >&2
}

check_oc_version() {
    local version minor
    need_command oc
    version=$(oc version --client 2>/dev/null || true)
    minor=$(printf '%s\n' "$version" | awk '/Client Version:/ {split($3, p, "."); print p[2]; exit}')
    [[ -n "$minor" && "$minor" -ge 14 ]] || { print_error 'OpenShift CLI 4.14 or newer is required'; return 1; }
}

check_oc_login() {
    oc whoami >/dev/null 2>&1 || { print_error "log in with 'oc login' before deploying"; return 1; }
    OPENSHIFT_SERVER=$(oc whoami --show-server) || return 1
    print_status "OpenShift target: $OPENSHIFT_SERVER / $PROJECT_NAME"
}

setup_project() {
    if resource_exists project "$PROJECT_NAME"; then
        confirm_target 'OpenShift deployment' "$PROJECT_NAME"
        run oc project "$PROJECT_NAME"
    else
        if [[ "${ADOPT_LEGACY_RESOURCES:-false}" == true ]]; then
            print_error "legacy adoption requires an existing OpenShift project '$PROJECT_NAME'"
            return 1
        fi
        run oc new-project "$PROJECT_NAME"
        run oc label namespace "$PROJECT_NAME" "$CEN_MANAGED_BY_LABEL" "$CEN_INSTANCE_KEY=$APP_NAME" --overwrite
    fi
}

capture_route_host() {
    oc get route "$1" -o jsonpath='{.spec.host}' 2>/dev/null || true
}

openshift_apps_domain() {
    oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null
}
