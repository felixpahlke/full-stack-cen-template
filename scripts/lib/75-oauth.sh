#!/usr/bin/env bash

readonly OAUTH2_PROXY_IMAGE='quay.io/oauth2-proxy/oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561'

is_oauth_enabled() { [[ "${OAUTH_ENABLED:-${DEPLOY_OAUTH:-true}}" == true ]]; }

ensure_oauth_upstream_password() {
    is_oauth_enabled || return 0
    local value=${OAUTH2_PROXY_UPSTREAM_PASSWORD:-} first_character
    first_character=${value:0:1}
    if [[ -z "$value" || "$value" == generate-on-first-dev-run || "$value" == replace-me || \
        "$value" == '<generate-a-random-upstream-password>' ]]; then
        need_command openssl
        OAUTH2_PROXY_UPSTREAM_PASSWORD=$(openssl rand -hex 32) || return 1
        print_success 'Generated the private OAuth proxy/backend seam credential without printing it.'
    elif is_placeholder_value "$value" || [[ ${#value} -lt 32 || -z "${value//$first_character/}" ]]; then
        print_error 'OAUTH2_PROXY_UPSTREAM_PASSWORD must be a non-placeholder random value of at least 32 characters.'
        return 1
    fi
}

oauth_public_host() {
    local domain
    domain=$(openshift_apps_domain) || return 1
    [[ -n "$domain" ]] || { print_error 'could not determine the OpenShift applications domain'; return 1; }
    printf 'oauth-proxy-%s.%s' "$PROJECT_NAME" "$domain"
}

create_oauth_proxy_secret() {
    local host
    if declare -F openshift_apps_domain >/dev/null; then host=$(oauth_public_host) || return 1
    else host=$(oc get route oauth-proxy -o jsonpath='{.spec.host}') || return 1
    fi
    # The seam is stored as OAUTH2_PROXY_BASIC_AUTH_PASSWORD via --from-env-file.
    create_oauth_env_secret "https://$host"
    add_deployment_output oauth_redirect_url "https://$host/oauth2/callback"
}

apply_oauth_workload() {
    if declare -F ensure_oc_resource_owned_or_absent >/dev/null; then ensure_oc_resource_owned_or_absent deployment oauth-proxy; fi
    if declare -F apply_resource >/dev/null; then
        apply_oauth_workload_manifest | apply_resource 'OAuth proxy workload'
    else
        apply_oauth_workload_manifest | oc apply -f -
    fi
}

apply_oauth_workload_manifest() {
    cat <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth-proxy
  labels: {app: oauth-proxy, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  replicas: 1
  selector: {matchLabels: {deployment: oauth-proxy}}
  template:
    metadata:
      labels: {deployment: oauth-proxy, app: oauth-proxy, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
    spec:
      containers:
        - name: oauth-proxy
          image: $OAUTH2_PROXY_IMAGE
          envFrom: [{secretRef: {name: $APP_NAME-oauth-proxy-secret}}]
          ports: [{name: oauth, containerPort: 4180}]
          args:
            - --provider=oidc
            - --pass-basic-auth=true
            - --pass-user-headers=true
            - --pass-authorization-header=false
            - --set-authorization-header=false
            - --skip-auth-strip-headers=true
            - --cookie-secure=true
            - --cookie-httponly=true
            - --cookie-samesite=lax
            - --insecure-oidc-allow-unverified-email
            - --upstream=http://backend:8000/api/
            - --upstream=http://frontend:8080/
            - --email-domain=*
            - --http-address=:4180
            - --skip-provider-button
          readinessProbe: {httpGet: {path: /ping, port: oauth}, initialDelaySeconds: 2, periodSeconds: 10}
          livenessProbe: {httpGet: {path: /ping, port: oauth}, initialDelaySeconds: 10, periodSeconds: 30}
EOF
}

apply_oauth_ingress() {
    local host
    host=$(oauth_public_host) || return 1
    ensure_oc_resource_owned_or_absent service oauth-proxy
    ensure_oc_resource_owned_or_absent route oauth-proxy
    cat <<EOF | apply_resource 'OAuth proxy ingress'
apiVersion: v1
kind: Service
metadata:
  name: oauth-proxy
  labels: {app: oauth-proxy, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  selector: {deployment: oauth-proxy}
  ports: [{name: oauth, port: 4180, targetPort: oauth}]
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: oauth-proxy
  labels: {app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  host: $host
  to: {kind: Service, name: oauth-proxy}
  port: {targetPort: oauth}
  tls: {termination: edge, insecureEdgeTerminationPolicy: Redirect}
EOF
    add_deployment_output oauth_proxy_url "$host"
}

deploy_oauth_proxy() {
    is_oauth_enabled || return 0
    apply_oauth_workload
    if declare -F run >/dev/null; then run oc rollout status deployment/oauth-proxy --timeout=15m
    else oc rollout status deployment/oauth-proxy --timeout=15m
    fi
    declare -F apply_resource >/dev/null || return 0
    print_success 'OAuth proxy workload is Ready; switching ingress now.'
    apply_oauth_ingress
    remove_direct_app_routes
}

create_oauth_proxy_service() { :; }
create_oauth_proxy_route() { apply_oauth_ingress; }
update_backend_with_oauth_url() { update_app_env_secret_with_urls; }
