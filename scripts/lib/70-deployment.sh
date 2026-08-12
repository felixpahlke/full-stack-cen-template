#!/usr/bin/env bash

legacy_resource_candidates() {
    local resources=(
        secret/git-secret "secret/$APP_NAME-env" secret/github-webhook-secret
        imagestream/backend buildconfig/backend deployment/backend service/backend route/backend
        rolebinding/webhook-access-unauthenticated
    )
    if [[ "$HAS_FRONTEND" == true ]]; then
        resources+=(imagestream/frontend buildconfig/frontend deployment/frontend service/frontend route/frontend)
    fi
    if [[ "$HAS_DATABASE" == true && "${POSTGRES_SERVER:-}" == postgresql ]]; then
        resources+=(pvc/postgresql-data deployment/postgresql service/postgresql)
    fi
    if [[ "$OAUTH_ENABLED" == true ]]; then
        resources+=("secret/$APP_NAME-oauth-proxy-secret" deployment/oauth-proxy service/oauth-proxy route/oauth-proxy)
    fi
    printf '%s\n' "${resources[@]}"
}

legacy_resource_matches_application() {
    local kind=$1 name=$2 json
    json=$(oc get "$kind" "$name" -o json) || return 1
    LEGACY_KIND=$kind LEGACY_NAME=$name LEGACY_APP_NAME=$APP_NAME LEGACY_GIT_URL=$GIT_SSH_URL \
        LEGACY_HAS_DATABASE=$HAS_DATABASE LEGACY_FLAVOR=$CEN_DEPLOY_FLAVOR node -e '
      const fs=require("node:fs"), x=JSON.parse(fs.readFileSync(0,"utf8"));
      const kind=process.env.LEGACY_KIND,name=process.env.LEGACY_NAME,app=process.env.LEGACY_APP_NAME;
      const data=x.data??{}, spec=x.spec??{};
      const container=(n)=>(spec.template?.spec?.containers??[]).find(c=>c.name===n);
      const port=(n)=>(spec.ports??[]).some(p=>Number(p.port)===n||Number(p.targetPort)===n);
      let ok=x.metadata?.name===name;
      if(kind==="secret"&&name==="git-secret") ok&&=x.type==="kubernetes.io/ssh-auth"&&!!data["ssh-privatekey"];
      else if(kind==="secret"&&name.endsWith("-env")) ok&&=!!data.PROJECT_NAME;
      else if(kind==="secret"&&name==="github-webhook-secret") ok&&=!!data.WebHookSecretKey;
      else if(kind==="secret"&&name.endsWith("-oauth-proxy-secret")) ok&&=!!data.OAUTH2_PROXY_CLIENT_ID;
      else if(kind==="buildconfig") {
        const component=name, context=component;
        ok&&=spec.source?.git?.uri===process.env.LEGACY_GIT_URL&&spec.source?.contextDir===context&&spec.source?.sourceSecret?.name==="git-secret";
        ok&&=spec.output?.to?.name===`${component}:latest`;
      } else if(kind==="imagestream") ok&&=["backend","frontend"].includes(name);
      else if(kind==="deployment") {
        if(name==="postgresql") ok&&=!!container("postgresql")&&String(container("postgresql").image??"").startsWith("postgres:")&&
          (spec.template?.spec?.volumes??[]).some(v=>v.persistentVolumeClaim?.claimName==="postgresql-data");
        else if(name==="oauth-proxy") ok&&=!!container("oauth-proxy")&&String(container("oauth-proxy").image??"").includes("oauth2-proxy");
        else ok&&=!!container(name);
      } else if(kind==="service") {
        const expected={backend:8000,frontend:8080,postgresql:5432,"oauth-proxy":4180}[name]; ok&&=port(expected);
      } else if(kind==="route") ok&&=spec.to?.name===name;
      else if(kind==="pvc") ok&&=(spec.accessModes??[]).includes("ReadWriteOnce")&&!!spec.resources?.requests?.storage;
      else if(kind==="rolebinding") ok&&=spec.roleRef?.kind==="ClusterRole"&&spec.roleRef?.name==="system:webhook"&&
        (spec.subjects??[]).some(s=>s.kind==="Group"&&s.name==="system:unauthenticated");
      else ok=false;
      process.exit(ok?0:1);' <<< "$json"
}

adopt_legacy_resources() {
    [[ "${ADOPT_LEGACY_RESOURCES:-false}" == true ]] || return 0
    local resource kind name managed instance confirmation
    local candidates=() adoptable=()
    while IFS= read -r resource; do [[ -z "$resource" ]] || candidates+=("$resource"); done < <(legacy_resource_candidates)
    for resource in buildconfig/backend deployment/backend service/backend; do
        resource_exists "${resource%%/*}" "${resource#*/}" || {
            print_error "legacy adoption refused: required application anchor $resource is absent"
            return 1
        }
    done
    for resource in "${candidates[@]}"; do
        kind=${resource%%/*}; name=${resource#*/}
        resource_exists "$kind" "$name" || continue
        managed=$(oc get "$kind" "$name" -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
        instance=$(oc get "$kind" "$name" -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null || true)
        if resource_is_owned_by_this_deployment "$managed" "$instance"; then continue; fi
        if [[ -n "$managed" || -n "$instance" ]] || ! legacy_resource_matches_application "$kind" "$name"; then
            print_error "legacy adoption refused: $resource is ambiguous or does not match this application"
            return 1
        fi
        adoptable+=("$resource")
    done
    ((${#adoptable[@]})) || { print_error 'legacy adoption refused: no unlabeled matching resources were found'; return 1; }
    print_warning 'Verified the following unlabeled legacy resources for adoption:'
    printf '  %s\n' "${adoptable[@]}" >&2
    read -r -p "Type 'adopt $PROJECT_NAME/$APP_NAME' to apply both ownership labels: " confirmation
    [[ "$confirmation" == "adopt $PROJECT_NAME/$APP_NAME" ]] || { print_error 'legacy adoption cancelled; no labels were changed'; return 1; }
    for resource in "${adoptable[@]}"; do
        run oc label "$resource" "$CEN_MANAGED_BY_LABEL" "$CEN_INSTANCE_KEY=$APP_NAME" --overwrite
        oc_resource_is_owned "${resource%%/*}" "${resource#*/}" || {
            print_error "legacy adoption could not verify both labels on $resource"
            return 1
        }
        print_success "Adopted $resource"
    done
}

preflight_deploy_collisions() {
    local resource kind name resources=(
        'secret/git-secret' "secret/$APP_NAME-env" 'secret/github-webhook-secret' 'imagestream/backend' 'buildconfig/backend'
        'deployment/backend' 'service/backend' 'rolebinding/webhook-access-unauthenticated'
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
    local component=$1 port=$2 context_dir=$3 dockerfile_path=$4 env_from='' context=''
    [[ "$component" != backend ]] || env_from="          envFrom: [{secretRef: {name: $APP_NAME-env}}]"
    [[ -z "$context_dir" ]] || context="    contextDir: $context_dir"
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
    git: {uri: "$GIT_SSH_URL", ref: "$DEPLOYMENT_BRANCH_FILTER"}
$context
    sourceSecret: {name: git-secret}
  strategy: {type: Docker, dockerStrategy: {dockerfilePath: $dockerfile_path}}
  output: {to: {kind: ImageStreamTag, name: "$component:latest"}}
  triggers:
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
    local component=$1 port=$2 context_dir=$3 dockerfile_path=$4
    ensure_oc_resource_owned_or_absent imagestream "$component"
    ensure_oc_resource_owned_or_absent buildconfig "$component"
    ensure_oc_resource_owned_or_absent deployment "$component"
    ensure_oc_resource_owned_or_absent service "$component"
    component_manifest "$component" "$port" "$context_dir" "$dockerfile_path" | apply_resource "$component multi-image workload"
}

start_component_build() {
    local component=$1 result_name=$2 build_ref
    oc_resource_is_owned buildconfig "$component" || { warn_unowned_collision buildconfig "$component"; return 1; }
    build_ref=$(oc start-build "$component" -o name)
    build_ref="build/${build_ref##*/}"
    printf -v "$result_name" '%s' "$build_ref"
    print_status "Started $build_ref."
}

wait_for_builds() {
    local build_refs=("$@") build_ref phase summary all_complete
    local deadline=$((SECONDS + 900)) last_report=$((SECONDS - 15))
    print_status "Waiting for builds: ${build_refs[*]}"
    while true; do
        summary=''; all_complete=true
        for build_ref in "${build_refs[@]}"; do
            [[ -n "$build_ref" ]] || continue
            phase=$(oc get "$build_ref" -o jsonpath='{.status.phase}' 2>/dev/null || true)
            [[ -n "$summary" ]] && summary+=', '
            summary+="$build_ref=${phase:-Pending}"
            case "$phase" in
                Complete) ;;
                Failed|Error|Cancelled)
                    print_error "$build_ref ended with $phase"
                    oc logs "$build_ref" --tail=80 >&2 || true
                    return 1
                    ;;
                *) all_complete=false ;;
            esac
        done
        if [[ "$all_complete" == true ]]; then print_success "Builds completed: $summary"; return 0; fi
        if ((SECONDS - last_report >= 15)); then print_status "Build progress: $summary"; last_report=$SECONDS; fi
        ((SECONDS < deadline)) || { print_error "timed out waiting for builds: $summary"; return 1; }
        sleep 5
    done
}

rollout_component() {
    local component=$1
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

deploy_components() {
    local backend_build frontend_build=''
    apply_component backend 8000 backend Dockerfile
    if [[ "$HAS_FRONTEND" == true ]]; then
        apply_component frontend 8080 '' frontend/Dockerfile
        configure_frontend
    fi

    start_component_build backend backend_build
    if [[ "$HAS_FRONTEND" == true ]]; then start_component_build frontend frontend_build; fi
    wait_for_builds "$backend_build" "$frontend_build"

    rollout_component backend
    if [[ "$HAS_FRONTEND" == true ]]; then rollout_component frontend; fi
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
    local route direct_routes
    direct_routes=$(find_direct_app_routes)
    if [[ -n "$direct_routes" ]]; then print_warning "Removing owned direct ingress after proxy readiness: ${direct_routes//$'\n'/ }"; fi
    while IFS= read -r route; do
        [[ -n "$route" ]] || continue
        if [[ "$route" == oauth-proxy ]]; then
            oc_resource_is_owned route "$route" || { warn_unowned_collision route "$route"; return 1; }
            print_warning 'Clearing direct alternate backends from owned route/oauth-proxy while preserving proxy ingress.'
            run oc patch route/oauth-proxy --type=merge --patch '{"spec":{"alternateBackends":null}}'
        else
            delete_owned_oc_resource route "$route"
        fi
    done <<< "$direct_routes"
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
