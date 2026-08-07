#!/usr/bin/env bash

preflight_deploy_collisions() {
    local resource kind name resources=(
        'secret/git-secret' "secret/$APP_NAME-env" 'secret/github-webhook-secret' 'imagestream/backend' 'buildconfig/backend'
        'deployment/backend' 'service/backend'
    )
    if [[ "$HAS_FRONTEND" == true ]]; then
        resources+=(imagestream/frontend buildconfig/frontend deployment/frontend service/frontend)
    fi
    if [[ "$HAS_DATABASE" == true && "${POSTGRES_SERVER:-}" == postgresql ]]; then
        resources+=(pvc/postgresql-data deployment/postgresql service/postgresql)
    fi
    if [[ "$OAUTH_ENABLED" == true ]]; then
        resources+=("secret/$APP_NAME-oauth-proxy-secret" deployment/oauth-proxy service/oauth-proxy route/oauth-proxy)
    else
        resources+=(route/backend)
        if [[ "$HAS_FRONTEND" == true ]]; then resources+=(route/frontend); fi
    fi
    for resource in "${resources[@]}"; do
        kind=${resource%%/*}; name=${resource#*/}
        ensure_oc_resource_owned_or_absent "$kind" "$name" || return 1
    done
}

component_manifest() {
    local component=$1 port=$2 context_dir=$3 env_from=''
    [[ "$component" != backend ]] || env_from="          envFrom: [{secretRef: {name: $APP_NAME-env}}]"
    cat <<EOF
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: $component
  labels: {$CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
---
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: $component
  labels: {$CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  runPolicy: SerialLatestOnly
  source:
    type: Git
    git: {uri: "$GIT_SSH_URL", ref: "${DEPLOYMENT_BRANCH_FILTER:-main}"}
    contextDir: $context_dir
    sourceSecret: {name: git-secret}
  strategy: {type: Docker, dockerStrategy: {dockerfilePath: Dockerfile}}
  output: {to: {kind: ImageStreamTag, name: "$component:latest"}}
  triggers:
    - {type: ConfigChange}
    - {type: ImageChange}
    - {type: GitHub, github: {secretReference: {name: github-webhook-secret}}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $component
  labels: {app: $component, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  replicas: 1
  selector: {matchLabels: {deployment: $component}}
  template:
    metadata:
      labels: {deployment: $component, app: $component, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
    spec:
      containers:
        - name: $component
          image: image-registry.openshift-image-registry.svc:5000/$PROJECT_NAME/$component:latest
          ports: [{name: http, containerPort: $port}]
$env_from
---
apiVersion: v1
kind: Service
metadata:
  name: $component
  labels: {app: $component, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  selector: {deployment: $component}
  ports: [{name: http, port: $port, targetPort: $port}]
EOF
}

apply_component() {
    local component=$1 port=$2 context_dir=$3
    ensure_oc_resource_owned_or_absent imagestream "$component"
    ensure_oc_resource_owned_or_absent buildconfig "$component"
    ensure_oc_resource_owned_or_absent deployment "$component"
    ensure_oc_resource_owned_or_absent service "$component"
    component_manifest "$component" "$port" "$context_dir" | apply_resource "$component multi-image workload"
}

wait_for_build() {
    local build_ref=$1 phase deadline=$((SECONDS + 900))
    while true; do
        phase=$(oc get "$build_ref" -o jsonpath='{.status.phase}' 2>/dev/null || true)
        case "$phase" in Complete) return 0 ;; Failed|Error|Cancelled) print_error "$build_ref ended with $phase"; return 1 ;; esac
        ((SECONDS < deadline)) || { print_error "timed out waiting for $build_ref"; return 1; }
        sleep 5
    done
}

build_component() {
    local component=$1 build_ref
    oc_resource_is_owned buildconfig "$component" || { warn_unowned_collision buildconfig "$component"; return 1; }
    build_ref=$(oc start-build "$component" -o name)
    wait_for_build "build/${build_ref##*/}"
    oc_resource_is_owned deployment "$component" || { warn_unowned_collision deployment "$component"; return 1; }
    run oc rollout restart "deployment/$component"
    run oc rollout status "deployment/$component" --timeout=15m
}

configure_frontend() {
    [[ "$HAS_FRONTEND" == true ]] || return 0
    local build_args='[' first=true line name value
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^(VITE_[A-Za-z0-9_]+)=(.*)$ ]] || continue
        name=${BASH_REMATCH[1]}; value=${!name-}
        [[ "$first" == true ]] || build_args+=','
        build_args+="{\"name\":\"$name\",\"value\":\"$value\"}"
        first=false
    done < "$ENV_FILE"
    build_args+=']'
    oc_resource_is_owned buildconfig frontend || { warn_unowned_collision buildconfig frontend; return 1; }
    run oc patch buildconfig/frontend --type=merge --patch "{\"spec\":{\"strategy\":{\"dockerStrategy\":{\"buildArgs\":$build_args}}}}"
}

deploy_frontend() {
    [[ "$HAS_FRONTEND" == true ]] || return 0
    apply_component frontend 8080 frontend
    configure_frontend
    build_component frontend
}

deploy_backend() {
    apply_component backend 8000 backend
    build_component backend
}

apply_direct_route() {
    local component=$1
    ensure_oc_resource_owned_or_absent route "$component"
    cat <<EOF | apply_resource "$component direct ingress"
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: $component
  labels: {app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  to: {kind: Service, name: $component}
  port: {targetPort: http}
  tls: {termination: edge, insecureEdgeTerminationPolicy: Redirect}
EOF
}

reconcile_direct_ingress() {
    [[ "$OAUTH_ENABLED" != true ]] || return 0
    apply_direct_route backend
    if [[ "$HAS_FRONTEND" == true ]]; then apply_direct_route frontend; fi
}

find_direct_app_routes() {
    local resources owned_deployments
    resources=$(oc get routes.route.openshift.io,services,deployments.apps -o json) || return 1
    owned_deployments=$(oc get deployments.apps -l "$(cen_ownership_labels)" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}') || return 1
    CEN_OWNED_DEPLOYMENTS=$owned_deployments node -e '
      const fs=require("node:fs"); const items=JSON.parse(fs.readFileSync(0,"utf8")||"{}").items??[];
      const owned=new Set((process.env.CEN_OWNED_DEPLOYMENTS??"").split("\n").filter(Boolean));
      const services=new Map(items.filter(x=>x.kind==="Service").map(x=>[x.metadata.name,x]));
      const deployments=items.filter(x=>x.kind==="Deployment"&&owned.has(x.metadata?.name));
      const selected=(s,d)=>{const q=s.spec?.selector??{},l=d.spec?.template?.metadata?.labels??{};return Object.keys(q).length&&Object.entries(q).every(([k,v])=>l[k]===v)};
      for(const route of items.filter(x=>x.kind==="Route")){
        const routePort=route.spec?.port?.targetPort; const backends=[route.spec?.to,...(route.spec?.alternateBackends??[])].filter(Boolean);
        const direct=backends.some(b=>{const s=services.get(b.name);if(!s)return false;const ds=deployments.filter(d=>selected(s,d));if(!ds.length)return false;
          return (s.spec?.ports??[]).filter(p=>routePort==null||String(p.name)===String(routePort)||String(p.port)===String(routePort)).some(p=>{
            const target=p.targetPort??p.port; return ds.some(d=>String(target)==="8000"||String(target)==="8080"||(d.spec?.template?.spec?.containers??[]).flatMap(c=>c.ports??[]).some(cp=>String(cp.name)===String(target)&&(cp.containerPort===8000||cp.containerPort===8080)))
          })}); if(direct)process.stdout.write(`${route.metadata.name}\n`)
      }' <<< "$resources"
}

preflight_oauth_ingress() {
    [[ "$OAUTH_ENABLED" == true ]] || return 0
    local route direct_routes unowned=false
    direct_routes=$(find_direct_app_routes)
    while IFS= read -r route; do
        [[ -n "$route" ]] || continue
        if ! oc_resource_is_owned route "$route"; then warn_unowned_collision route "$route"; unowned=true; fi
    done <<< "$direct_routes"
    [[ "$unowned" == false ]] || { print_error 'OAuth conversion cannot continue while an unowned direct application Route exists'; return 1; }
}

remove_direct_app_routes() {
    [[ "$OAUTH_ENABLED" == true ]] || return 0
    local route direct_routes resources=()
    direct_routes=$(find_direct_app_routes)
    while IFS= read -r route; do [[ -z "$route" ]] || resources+=("route/$route"); done <<< "$direct_routes"
    if ((${#resources[@]})); then print_warning "Removing owned direct ingress after proxy readiness: ${resources[*]}"; fi
    for route in "${resources[@]}"; do delete_owned_oc_resource route "${route#route/}"; done
    direct_routes=$(find_direct_app_routes)
    [[ -z "$direct_routes" ]] || { print_error "direct application Routes remain: ${direct_routes//$'\n'/ }"; return 1; }
}

configure_backend() { :; }
group_resources() { :; }

reconcile_obsolete_resources() {
    if [[ "$OAUTH_ENABLED" != true ]]; then
        delete_owned_oc_resource route oauth-proxy
        delete_owned_oc_resource service oauth-proxy
        delete_owned_oc_resource deployment oauth-proxy
        delete_owned_oc_resource secret "$APP_NAME-oauth-proxy-secret"
    fi
    if [[ "$HAS_DATABASE" != true ]]; then
        delete_owned_oc_resource deployment postgresql
        delete_owned_oc_resource service postgresql
        print_status 'Preserving any PostgreSQL PVC for recovery.'
    fi
}
