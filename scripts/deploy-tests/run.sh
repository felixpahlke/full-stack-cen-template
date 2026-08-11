#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_TMP=$(mktemp -d)
trap 'rm -rf -- "$TEST_TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"; }
assert_absent() { if grep -Fq -- "$2" "$1"; then fail "$1 unexpectedly contains: $2"; fi; }
line_number() { grep -Fnm1 -- "$2" "$1" | cut -d: -f1; }
assert_before() {
    local first second
    first=$(line_number "$1" "$2") || fail "$1 lacks: $2"
    second=$(line_number "$1" "$3") || fail "$1 lacks: $3"
    ((first < second)) || fail "$1 does not place '$2' before '$3'"
}

FLAVOR=$(sed -n 's/^CEN_DEPLOY_FLAVOR=//p' "$ROOT/scripts/deploy-flavor.conf")
case "$FLAVOR" in
    local-auth|local-auth-custom-ui) HAS_FRONTEND=true; HAS_DATABASE=true; OAUTH=false ;;
    oauth-proxy|oauth-proxy-custom-ui) HAS_FRONTEND=true; HAS_DATABASE=true; OAUTH=true ;;
    backend-only) HAS_FRONTEND=false; HAS_DATABASE=true; OAUTH=false ;;
    backend-only-no-db) HAS_FRONTEND=false; HAS_DATABASE=false; OAUTH=false ;;
    *) fail "unknown branch flavor: $FLAVOR" ;;
esac

safe_resource_name() { printf '%s' "$1" | tr './' '__'; }

make_env() {
    local destination=$1
    cat > "$destination" <<'EOF'
_CEN_FLAVOR=poisoned-metadata
_APP_NAME=app-a
PROJECT_NAME=mock-project
ENVIRONMENT=production
FIRST_SUPERUSER=admin@example.com
FIRST_SUPERUSER_PASSWORD=superuser-secret-value
SECRET_KEY=application-secret-value-0123456789abcdef
API_KEY=api-key-value-0123456789abcdefXX
POSTGRES_SERVER=external.postgres.example
POSTGRES_PORT=5432
POSTGRES_DB=app
POSTGRES_USER=app
POSTGRES_PASSWORD=database-secret-value
BACKEND_CORS_ORIGINS=https://admin.example.com
MIGRATE_ON_START=true
OAUTH2_PROXY_COOKIE_SECRET=oauth-cookie-secret-value-0123456789
OAUTH2_PROXY_CLIENT_ID=client-id
OAUTH2_PROXY_CLIENT_SECRET=oauth-client-secret-value
OAUTH2_PROXY_OIDC_ISSUER_URL=https://idp.example.com/oidc
OAUTH2_PROXY_UPSTREAM_PASSWORD=upstream-secret-value-0123456789abcdef0123456789abcdef
OAUTH2_PROXY_COOKIE_SECURE=false
VITE_API_URL=
VITE_TELEMETRY_ENABLED=true
_GIT_SSH_URL=git@github.com:owner/repository.git
_GITHUB_TOKEN=github-token-secret-value
_DEPLOYMENT_BRANCH_FILTER=
_IAM_API_KEY=registry-secret-value
_IBM_CLOUD_RESOURCE_GROUP=mock-group
_IBM_CLOUD_REGION=eu-de
_IBM_CLOUD_ACCOUNT_NAME=mock-account
_CE_PROJECT_NAME=mock-project
_CR_REGISTRY=de.icr.io
_CR_NAMESPACE=mock-namespace
GITHUB_TOKEN=must-not-reach-application
IAM_API_KEY=must-not-reach-application
DEPLOY_DRY_RUN=false
PATH=/poisoned
EOF
}

put_resource() {
    local state=$1 kind=$2 name=$3 instance=${4:-app-a} safe
    safe=$(safe_resource_name "$kind")
    printf 'cen-template|%s\n' "$instance" > "$state/resources/${safe}__${name}"
}

put_legacy_resource() {
    local state=$1 kind=$2 name=$3 safe json
    safe=$(safe_resource_name "$kind")
    printf '|\n' > "$state/resources/${safe}__${name}"
    json="$state/json/${safe}__${name}.json"
    LEGACY_KIND=$kind LEGACY_NAME=$name node -e '
      const fs=require("node:fs"),kind=process.env.LEGACY_KIND,name=process.env.LEGACY_NAME;
      const x={metadata:{name}};
      if(kind==="secret"){
        x.type=name==="git-secret"?"kubernetes.io/ssh-auth":"Opaque";
        x.data=name==="git-secret"?{"ssh-privatekey":"eA=="}:name==="github-webhook-secret"?{WebHookSecretKey:"eA=="}:
          name.endsWith("-oauth-proxy-secret")?{OAUTH2_PROXY_CLIENT_ID:"eA=="}:{PROJECT_NAME:"eA=="};
      } else if(kind==="buildconfig") x.spec={source:{git:{uri:"git@github.com:owner/repository.git"},contextDir:name,sourceSecret:{name:"git-secret"}},output:{to:{name:`${name}:latest`}}};
      else if(kind==="imagestream") x.spec={};
      else if(kind==="deployment"){
        const image=name==="postgresql"?"postgres:12":name==="oauth-proxy"?"quay.io/oauth2-proxy/oauth2-proxy:v7":"registry/mock/"+name+":latest";
        x.spec={template:{spec:{containers:[{name,image}],volumes:name==="postgresql"?[{persistentVolumeClaim:{claimName:"postgresql-data"}}]:[]}}};
      } else if(kind==="service") x.spec={ports:[{port:{backend:8000,frontend:8080,postgresql:5432,"oauth-proxy":4180}[name]}]};
      else if(kind==="route") x.spec={to:{name}};
      else if(kind==="pvc") x.spec={accessModes:["ReadWriteOnce"],resources:{requests:{storage:"1Gi"}}};
      else if(kind==="rolebinding") x.spec={roleRef:{kind:"ClusterRole",name:"system:webhook"},subjects:[{kind:"Group",name:"system:unauthenticated"}]};
      fs.writeFileSync(process.argv[1],JSON.stringify(x));' "$json"
}

make_mocks() {
    local bin=$1
    mkdir -p "$bin"; : > "$bin/.cen-deploy-mock-bin"
    cat > "$bin/docker" <<'EOF'
#!/usr/bin/env bash
# cen-deploy-mock-command
command_name=${0##*/}
if env | grep -Eq '^(GITHUB_TOKEN|IAM_API_KEY|POSTGRES_PASSWORD|OAUTH2_PROXY_CLIENT_SECRET|OAUTH2_PROXY_COOKIE_SECRET|OAUTH2_PROXY_UPSTREAM_PASSWORD)='; then printf 'ENV_LEAK %s\n' "$command_name" >> "$MOCK_LOG"; fi
printf '%s' "$command_name" >> "$MOCK_LOG"; printf ' %q' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
EOF
    cat > "$bin/git" <<'EOF'
#!/usr/bin/env bash
# cen-deploy-mock-command
printf 'git' >> "$MOCK_LOG"; printf ' %q' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
args=" $* "; ref=${*: -1}
if [[ "$args" == *' ls-remote '* ]]; then
  if [[ "${MOCK_GIT_MISSING_REF:-false}" == true || "$ref" == refs/heads/does-not-exist ]]; then exit 2; fi
  printf '0123456789abcdef0123456789abcdef01234567\t%s\n' "$ref"
  exit 0
fi
exit 0
EOF
    cat > "$bin/ibmcloud" <<'EOF'
#!/usr/bin/env bash
# cen-deploy-mock-command
if env | grep -Eq '^(GITHUB_TOKEN|IAM_API_KEY|POSTGRES_PASSWORD|OAUTH2_PROXY_CLIENT_SECRET|OAUTH2_PROXY_COOKIE_SECRET|OAUTH2_PROXY_UPSTREAM_PASSWORD)='; then printf 'ENV_LEAK ibmcloud\n' >> "$MOCK_LOG"; fi
printf 'ibmcloud' >> "$MOCK_LOG"; printf ' %q' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
args=" $* "; name=''; previous=''
for argument in "$@"; do
  [[ "$previous" == --name ]] && name=$argument
  if [[ "$previous" == --from-env-file || "$previous" == --password-from-file ]]; then
    printf '%s\n' "$argument" >> "$MOCK_TEMP_FILES"
    [[ "$previous" != --from-env-file ]] || cp "$argument" "$MOCK_SECRETS/${name}.env"
  fi
  previous=$argument
done
safe_kind() { printf '%s' "$1" | tr './' '__'; }
resource_file() { printf '%s/resources/%s__%s' "$MOCK_STATE" "$(safe_kind "$1")" "$2"; }
if [[ "$args" == *' account show '* ]]; then printf 'Account Name: mock-account\n'; exit 0; fi
if [[ "$args" == *' ce project current '* ]]; then printf 'Subdomain: mock.mockcluster\n'; exit 0; fi
if [[ "$args" == *' ce project get '* ]]; then
  [[ "${MOCK_CE_PROJECT_ABSENT:-false}" != true || -f "$MOCK_STATE/ce-project-created" ]]; exit
fi
if [[ "$args" == *' ce project create '* ]]; then touch "$MOCK_STATE/ce-project-created"; exit 0; fi
if [[ "$args" == *' plugin show '* ]]; then exit 0; fi
if [[ "$args" == *' cr namespace-list '* ]]; then printf 'mock-namespace\n'; exit 0; fi
if [[ "$args" == *' ce registry get '* ]]; then [[ -f "$MOCK_STATE/registries/$name" ]]; exit; fi
if [[ "$args" == *' ce registry create '* ]]; then touch "$MOCK_STATE/registries/$name"; : > "$(resource_file secret "$name")"; exit 0; fi
if [[ "$args" == *' ce registry delete '* ]]; then rm -f "$MOCK_STATE/registries/$name" "$(resource_file secret "$name")"; exit 0; fi
if [[ "$args" == *' ce secret create '* ]]; then : > "$(resource_file secret "$name")"; exit 0; fi
if [[ "$args" == *' ce secret delete '* ]]; then rm -f "$(resource_file secret "$name")" "$MOCK_SECRETS/$name.env"; exit 0; fi
if [[ "$args" == *' ce application get '* ]]; then
  [[ -f "$(resource_file services.serving.knative.dev "$name")" ]] || exit 1
  printf 'https://%s.mock.codeengine.example\n' "$name"; exit 0
fi
if [[ "$args" == *' ce application update '* && "$args" == *' --visibility project '* ]]; then
  if [[ "${MOCK_VISIBILITY_UNKNOWN:-false}" == true ]]; then printf 'authentication unavailable\n' >&2; exit 41; fi
  if [[ ! -f "$(resource_file services.serving.knative.dev "$name")" ]]; then printf "Application '%s' not found\n" "$name" >&2; exit 1; fi
  exit 0
fi
if [[ "$args" == *' ce application create '* ]]; then : > "$(resource_file services.serving.knative.dev "$name")"; exit 0; fi
if [[ "$args" == *' ce application update '* ]]; then exit 0; fi
if [[ "$args" == *' ce application delete '* ]]; then rm -f "$(resource_file services.serving.knative.dev "$name")"; exit 0; fi
exit 0
EOF
    cat > "$bin/kubectl" <<'EOF'
#!/usr/bin/env bash
# cen-deploy-mock-command
printf 'kubectl' >> "$MOCK_LOG"; printf ' %q' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
safe_kind() { printf '%s' "$1" | tr './' '__'; }
resource_file() { printf '%s/resources/%s__%s' "$MOCK_STATE" "$(safe_kind "$1")" "$2"; }
action=${1:-}; kind=${2:-}; name=${3:-}; file=$(resource_file "$kind" "$name")
if [[ "$action" == label ]]; then printf 'cen-template|app-a\n' > "$file"; exit 0; fi
if [[ "$action" != get || ! -f "$file" ]]; then
  [[ "$action" != get ]] || printf 'Error from server (NotFound): %s/%s not found\n' "$kind" "$name" >&2
  exit 1
fi
IFS='|' read -r managed instance < "$file"
args=" $* "
if [[ "$args" == *'managed-by'* ]]; then printf '%s' "$managed"; fi
if [[ "$args" == *'instance'* ]]; then printf '%s' "$instance"; fi
if [[ "$args" == *' -o name '* ]]; then printf '%s/%s\n' "$kind" "$name"; fi
EOF
    cat > "$bin/curl" <<'EOF'
#!/usr/bin/env bash
# cen-deploy-mock-command
if env | grep -Eq '^(GITHUB_TOKEN|IAM_API_KEY|POSTGRES_PASSWORD|OAUTH2_PROXY_CLIENT_SECRET|OAUTH2_PROXY_COOKIE_SECRET|OAUTH2_PROXY_UPSTREAM_PASSWORD)='; then printf 'ENV_LEAK curl\n' >> "$MOCK_LOG"; fi
printf 'curl' >> "$MOCK_LOG"; printf ' %q' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
previous=''; args=" $* "; output_file=''
for argument in "$@"; do
  [[ "$previous" != --config ]] || printf '%s\n' "$argument" >> "$MOCK_TEMP_FILES"
  [[ "$previous" != --output ]] || output_file=$argument
  [[ "$argument" != @* ]] || printf '%s\n' "${argument#@}" >> "$MOCK_TEMP_FILES"
  previous=$argument
done
if [[ "$args" == *'/keys '* ]]; then printf '[{"id":1,"key":"ssh-ed25519 AAAATEST mock"}]'; exit 0; fi
if [[ "$args" == *'/hooks '* ]]; then
  if [[ "$args" == *' --request POST '* ]]; then
    [[ "${MOCK_WEBHOOK_POST_FAIL:-false}" != true ]] || { [[ -z "$output_file" ]] || printf '{"message":"failed"}' > "$output_file"; printf '500'; exit 0; }
    [[ -z "$output_file" ]] || printf '{"id":1}' > "$output_file"; printf '201'
  else
    [[ -z "$output_file" ]] || printf '[]' > "$output_file"; printf '200'
  fi
  exit 0
fi
EOF
    cat > "$bin/oc" <<'EOF'
#!/usr/bin/env bash
# cen-deploy-mock-command
if env | grep -Eq '^(GITHUB_TOKEN|IAM_API_KEY|POSTGRES_PASSWORD|OAUTH2_PROXY_CLIENT_SECRET|OAUTH2_PROXY_COOKIE_SECRET|OAUTH2_PROXY_UPSTREAM_PASSWORD|WEBHOOK_SECRET_VALUE)='; then printf 'ENV_LEAK oc\n' >> "$MOCK_LOG"; fi
printf 'oc' >> "$MOCK_LOG"; printf ' %q' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
args=" $* "; safe_kind() { printf '%s' "$1" | tr './' '__'; }; resource_file() { printf '%s/resources/%s__%s' "$MOCK_STATE" "$(safe_kind "$1")" "$2"; }
if [[ "$args" == *' version --client '* ]]; then printf 'Client Version: 4.18.0\n'; exit 0; fi
if [[ "$args" == *' whoami --show-server '* ]]; then printf 'https://api.mock.openshift.example'; exit 0; fi
if [[ "$args" == *' whoami '* ]]; then printf 'mock-user'; exit 0; fi
if [[ "$args" == *' auth can-i '* ]]; then
  if [[ "${MOCK_WEBHOOK_RBAC_DENIED:-false}" == true && "$args" == *' bind clusterroles.rbac.authorization.k8s.io/system:webhook '* ]]; then printf 'no'
  elif [[ "${MOCK_REGISTRY_READ_DENIED:-false}" == true ]]; then printf 'no'
  else printf 'yes'
  fi
  exit 0
fi
if [[ "$args" == *' get ingress.config.openshift.io cluster '* ]]; then printf 'apps.mock.example'; exit 0; fi
if [[ "$args" == *' get configs.imageregistry.operator.openshift.io cluster '*'.spec.managementState'* ]]; then [[ "${MOCK_REGISTRY_UNREADY:-false}" == true ]] && printf 'Removed' || printf 'Managed'; exit 0; fi
if [[ "$args" == *' get configs.imageregistry.operator.openshift.io cluster '*'.spec.storage'* ]]; then [[ "${MOCK_REGISTRY_UNREADY:-false}" == true ]] && printf '{}' || printf '{"emptyDir":{}}'; exit 0; fi
if [[ "$args" == *' get endpoints image-registry '* ]]; then [[ "${MOCK_REGISTRY_UNREADY:-false}" == true ]] || printf '10.0.0.1'; exit 0; fi
if [[ "$args" == *' registry info '* ]]; then printf 'registry.mock'; exit 0; fi
if [[ "$args" == *' exec deployment/postgresql -- printenv '* ]]; then
  key=${*: -1}; file="$MOCK_STATE/postgres-$key"
  [[ -f "$file" ]] || exit 1
  cat "$file"; exit 0
fi
if [[ "$args" == *' get routes.route.openshift.io,services,deployments.apps '* ]]; then
  direct=false; unowned=false
  [[ -f "$MOCK_STATE/direct-route" && ! -f "$MOCK_STATE/direct-deleted" ]] && direct=true
  [[ -f "$MOCK_STATE/direct-unowned" ]] && unowned=true
  node -e '
    const direct=process.argv[1]==="true",unowned=process.argv[2]==="true";const items=[
      {kind:"Service",metadata:{name:"backend"},spec:{selector:{deployment:"backend"},ports:[{name:"http",port:8000,targetPort:8000}]}},
      {kind:"Service",metadata:{name:"safe"},spec:{selector:{deployment:"safe"},ports:[{name:"web",port:80,targetPort:8081}]}},
      {kind:"Deployment",metadata:{name:"backend"},spec:{template:{metadata:{labels:{deployment:"backend"}},spec:{containers:[{name:"backend",ports:[]}]}}}}
    ]; if(direct)items.push({kind:"Route",metadata:{name:"weighted-direct",labels:unowned?{}:{"app.kubernetes.io/managed-by":"cen-template","app.kubernetes.io/instance":"app-a"}},spec:{to:{name:"safe"},alternateBackends:[{name:"backend",weight:10}],port:{targetPort:8000}}});process.stdout.write(JSON.stringify({items}))' "$direct" "$unowned"
  exit 0
fi
if [[ "$args" == *' get deployments.apps '* && "$args" == *'app.kubernetes.io/instance=app-a'* ]]; then printf 'backend\nfrontend\n'; exit 0; fi
if [[ "$args" == *' get build/'* && "$args" == *'.status.phase'* ]]; then printf 'Complete'; exit 0; fi
if [[ "$args" == *' start-build '* ]]; then name='backend'; [[ "$args" == *' frontend '* ]] && name=frontend; printf 'build.build.openshift.io/%s-1\n' "$name"; exit 0; fi
if [[ "$args" == *' create secret generic '* && "$args" == *' -o yaml '* ]]; then
  name=''; previous=''; key=''; file=''
  for argument in "$@"; do
    [[ "$previous" != generic ]] || name=$argument
    case "$argument" in
      --from-env-file=*) file=${argument#*=}; printf '%s\n' "$file" >> "$MOCK_TEMP_FILES"; cp "$file" "$MOCK_SECRETS/$name.env" ;;
      --from-file=*) pair=${argument#*=}; key=${pair%%=*}; file=${pair#*=}; [[ "$(basename "$file")" != cen-deploy.* ]] || printf '%s\n' "$file" >> "$MOCK_TEMP_FILES"; cp "$file" "$MOCK_SECRETS/$name.$key" ;;
    esac
    previous=$argument
  done
  printf 'cen-template|app-a\n' > "$(resource_file secret "$name")"
  printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: %s\n' "$name"
  exit 0
fi
if [[ "$args" == *' apply '* && "$args" == *' -f - '* ]]; then
  input=$(cat); printf '%s\n---MOCK-DOCUMENT---\n' "$input" >> "$MOCK_MANIFESTS"
  if [[ "$input" == *'kind: RoleBinding'* ]]; then
    if [[ "${MOCK_WEBHOOK_RBAC_APPLY_FAILURE:-}" == forbidden ]]; then
      printf 'Error from server (Forbidden): rolebindings.rbac.authorization.k8s.io "webhook-access-unauthenticated" is forbidden: user cannot bind clusterrole system:webhook\n' >&2
      exit 1
    elif [[ "${MOCK_WEBHOOK_RBAC_APPLY_FAILURE:-}" == invalid ]]; then
      printf 'error: error parsing STDIN: error converting YAML to JSON\n' >&2
      exit 1
    fi
  fi
  if [[ "$input" == *'name: oauth-proxy'* && "$input" == *'kind: Route'* ]]; then printf 'MOCK_EVENT oauth-ingress-switched\n' >> "$MOCK_LOG"; fi
  while IFS='|' read -r kind name; do
    case "$kind" in PersistentVolumeClaim) kind=pvc ;; Deployment) kind=deployment ;; Service) kind=service ;; Route) kind=route ;; BuildConfig) kind=buildconfig ;; ImageStream) kind=imagestream ;; Secret) kind=secret ;; RoleBinding) kind=rolebinding ;; esac
    [[ -z "$kind" || -z "$name" ]] || printf 'cen-template|app-a\n' > "$(resource_file "$kind" "$name")"
  done < <(printf '%s\n' "$input" | awk '/^kind: /{k=$2;n=""} /^  name: / && n==""{n=$2;print k "|" n}')
  exit 0
fi
if [[ "${1:-}" == get ]]; then
  kind=${2:-}; name=${3:-}; file=$(resource_file "$kind" "$name")
  if [[ "$kind" == project && "$name" == mock-project ]]; then exit 0; fi
  if [[ "$kind" == route && "$args" == *'.spec.host'* && -f "$file" ]]; then printf '%s-mock-project.apps.mock.example' "$name"; exit 0; fi
  [[ -f "$file" ]] || exit 1
  if [[ "$args" == *' -o json '* ]]; then cat "$MOCK_STATE/json/$(safe_kind "$kind")__${name}.json"; exit; fi
  IFS='|' read -r managed instance < "$file"
  if [[ "$args" == *'managed-by'* ]]; then printf '%s' "$managed"; fi
  if [[ "$args" == *'instance'* ]]; then printf '%s' "$instance"; fi
  if [[ "$kind" == secret && "$args" == *'.data.'* ]]; then
    key=${args##*.data.}; key=${key%%\}*}; [[ -f "$MOCK_SECRETS/$name.$key" ]] || exit 1; base64 < "$MOCK_SECRETS/$name.$key" | tr -d '\n'
  fi
  exit 0
fi
if [[ "${1:-}" == label ]]; then
  resource=${2:-}; kind=${resource%%/*}; name=${resource#*/}; printf 'cen-template|app-a\n' > "$(resource_file "$kind" "$name")"; exit 0
fi
if [[ "$args" == *' delete route/weighted-direct '* ]]; then touch "$MOCK_STATE/direct-deleted"; rm -f "$(resource_file route weighted-direct)"; exit 0; fi
if [[ "${1:-}" == delete ]]; then resource=${2:-}; kind=${resource%%/*}; name=${resource#*/}; rm -f "$(resource_file "$kind" "$name")"; exit 0; fi
exit 0
EOF
    chmod +x "$bin"/*
}

prepare_case() {
    local name=$1
    CASE_DIR="$TEST_TMP/$name"; STATE="$CASE_DIR/state"; PROJECT="$CASE_DIR/project"
    mkdir -p "$STATE/resources" "$STATE/registries" "$STATE/secrets" "$STATE/ssh" "$STATE/json" "$PROJECT/frontend"
    cp -R "$ROOT/scripts" "$PROJECT/scripts"
    if [[ "$HAS_FRONTEND" == true ]]; then cp "$ROOT/frontend/Dockerfile" "$ROOT/frontend/nginx.conf" "$PROJECT/frontend/"; fi
    make_env "$PROJECT/.env.production"
    printf 'private\n' > "$STATE/ssh/ocp-key"
    printf 'ssh-ed25519 AAAATEST mock\n' > "$STATE/ssh/ocp-key.pub"
    : > "$STATE/calls.log"; : > "$STATE/manifests.log"; : > "$STATE/temp-files.log"; : > "$STATE/terminal.log"
    make_mocks "$STATE/bin"
}

run_with_mocks() {
    local output=$1 input=$2; shift 2
    printf '%b' "$input" | (
        cd "$PROJECT"
        PATH="$STATE/bin:$PATH" MOCK_LOG="$STATE/calls.log" MOCK_MANIFESTS="$STATE/manifests.log" \
        MOCK_TEMP_FILES="$STATE/temp-files.log" MOCK_SECRETS="$STATE/secrets" MOCK_STATE="$STATE" \
        CEN_DEPLOY_TERMINAL_FILE="$STATE/terminal.log" \
        CEN_DEPLOY_MOCK=true CEN_DEPLOY_MOCK_BIN="$STATE/bin" CEN_DEPLOY_SSH_DIR="$STATE/ssh" "$@"
    ) > "$output" 2>&1
}

assert_no_secret_leak() {
    local file=$1 value
    for value in superuser-secret-value application-secret-value database-secret-value oauth-cookie-secret-value \
        oauth-client-secret-value upstream-secret-value registry-secret-value github-token-secret-value must-not-reach-application; do
        assert_absent "$file" "$value"
    done
}

assert_temp_cleanup() {
    local temp_file
    while IFS= read -r temp_file; do [[ -z "$temp_file" || ! -e "$temp_file" ]] || fail "secret temp file survived: $temp_file"; done < "$STATE/temp-files.log"
}

run_ce_success() {
    local container_cli=${1:-docker} build_command
    prepare_case ce-success
    if [[ "$container_cli" == podman ]]; then mv "$STATE/bin/docker" "$STATE/bin/podman"; fi
    if [[ "$container_cli" == docker ]]; then build_command='docker image build'; else build_command='podman build'; fi
    put_resource "$STATE" secret mock-project-registry-secret app-a; touch "$STATE/registries/mock-project-registry-secret"
    put_resource "$STATE" secret mock-project-backend-config app-a
    printf 'STALE_KEY=must-disappear\n' > "$STATE/secrets/mock-project-backend-config.env"
    if [[ "$OAUTH" == true ]]; then
        put_resource "$STATE" services.serving.knative.dev mock-project-backend app-a
        put_resource "$STATE" services.serving.knative.dev mock-project-frontend app-a
    fi
    local output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n' bash -x ./scripts/ce-deploy.sh || { sed -n '1,220p' "$output" >&2; fail 'Code Engine success case failed'; }
    assert_absent "$STATE/calls.log" ENV_LEAK
    assert_contains "$STATE/calls.log" 'app.kubernetes.io/managed-by=cen-template app.kubernetes.io/instance=app-a'
    assert_contains "$STATE/calls.log" '--password-from-file'
    assert_absent "$STATE/calls.log" '--password registry-secret-value'
    assert_contains "$STATE/calls.log" 'ce secret delete --name mock-project-backend-config --force'
    assert_absent "$STATE/secrets/mock-project-backend-config.env" STALE_KEY
    assert_absent "$STATE/secrets/mock-project-backend-config.env" GITHUB_TOKEN
    assert_absent "$STATE/secrets/mock-project-backend-config.env" IAM_API_KEY
    assert_absent "$STATE/secrets/mock-project-backend-config.env" OAUTH2_PROXY_CLIENT_SECRET
    assert_contains "$STATE/secrets/mock-project-backend-config.env" "CEN_FLAVOR=$FLAVOR"
    if [[ "$HAS_FRONTEND" == true ]]; then [[ $(grep -Fc "$build_command" "$STATE/calls.log") == 2 ]] || fail 'expected two Code Engine images';
        if [[ "$OAUTH" == true ]]; then
            assert_contains "$STATE/calls.log" '--build-arg=VITE_API_URL=https://oauth-proxy.mockcluster.eu-de.codeengine.appdomain.cloud'
            assert_contains "$PROJECT/.env.production" 'VITE_API_URL=https://oauth-proxy.mockcluster.eu-de.codeengine.appdomain.cloud'
        else
            assert_contains "$STATE/calls.log" '--build-arg=VITE_API_URL=https://mock-project-backend.mockcluster.eu-de.codeengine.appdomain.cloud'
            assert_contains "$PROJECT/.env.production" 'VITE_API_URL=https://mock-project-backend.mockcluster.eu-de.codeengine.appdomain.cloud'
        fi
    else [[ $(grep -Fc "$build_command" "$STATE/calls.log") == 1 ]] || fail 'expected one Code Engine image'; fi
    if [[ "$container_cli" == podman ]]; then
        assert_absent "$STATE/calls.log" '--load'
        assert_contains "$STATE/calls.log" 'podman push'
    fi
    assert_contains "$PROJECT/.env.production" 'BACKEND_CORS_ORIGINS=https://admin.example.com'
    if [[ "$HAS_FRONTEND" == true && "$OAUTH" != true ]]; then assert_contains "$PROJECT/.env.production" 'mock-project-frontend.mockcluster.eu-de.codeengine.appdomain.cloud'; fi
    if [[ "$OAUTH" == true ]]; then assert_contains "$PROJECT/.env.production" 'oauth-proxy.mockcluster.eu-de.codeengine.appdomain.cloud'; fi
    if [[ "$HAS_FRONTEND" != true ]]; then assert_absent "$PROJECT/.env.production" 'BACKEND_CORS_ORIGINS=*'; fi
    if [[ "$OAUTH" != true ]]; then
        assert_contains "$output" 'Backend: https://mock-project-backend.mock.codeengine.example'
        if [[ "$HAS_FRONTEND" == true ]]; then assert_contains "$output" 'Frontend: https://mock-project-frontend.mock.codeengine.example'; fi
    fi
    if [[ "$OAUTH" == true ]]; then
        assert_before "$STATE/calls.log" 'ce application update --name mock-project-backend --visibility project' 'cr login'
        assert_before "$STATE/calls.log" 'ce application update --name mock-project-frontend --visibility project' "$build_command"
        assert_contains "$STATE/calls.log" 'oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561'
        assert_contains "$STATE/calls.log" '--argument=--cookie-secure=true'
        assert_contains "$PROJECT/.env.production" 'OAUTH2_PROXY_REDIRECT_URL=https://oauth-proxy.mockcluster.eu-de.codeengine.appdomain.cloud/oauth2/callback'
        assert_contains "$PROJECT/.env.production" 'OAUTH2_PROXY_WELL_KNOWN_URL=https://idp.example.com/oidc/.well-known/openid-configuration'
        assert_contains "$output" 'OAuth redirect URL: https://oauth-proxy.mockcluster.eu-de.codeengine.appdomain.cloud/oauth2/callback'
    fi
    assert_no_secret_leak "$output"; assert_no_secret_leak "$STATE/calls.log"; assert_temp_cleanup
    pass "Code Engine $FLAVOR topology, ownership, absence, exact secret sync, and trace leak probe"
}

run_ce_collision() {
    prepare_case ce-isolation
    put_resource "$STATE" services.serving.knative.dev mock-project-backend app-b
    local output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' ./scripts/ce-deploy.sh; then fail 'Code Engine mutated an app-b collision'; fi
    assert_contains "$output" 'application/mock-project-backend exists but is not owned by this deployment'
    assert_absent "$STATE/calls.log" 'docker image build'
    assert_absent "$STATE/calls.log" 'ce application delete --name mock-project-backend'
    pass 'Code Engine app-a refuses app-b at the expected name'
}

run_ce_confirmation() {
    prepare_case ce-confirmation
    local output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'wrong\n' ./scripts/ce-deploy.sh; then fail 'Code Engine accepted wrong confirmation'; fi
    assert_absent "$STATE/calls.log" 'ce project select'
    assert_absent "$STATE/calls.log" 'docker image build'
    pass 'Code Engine target confirmation gates mutations'
}

prepare_oc_direct_fixture() {
    put_resource "$STATE" deployment backend app-a; put_resource "$STATE" service backend app-a
    put_resource "$STATE" deployment frontend app-a; put_resource "$STATE" service frontend app-a
    put_resource "$STATE" route weighted-direct app-a; touch "$STATE/direct-route"
}

run_oc_success() {
    prepare_case oc-success
    sed -i.bak 's/POSTGRES_SERVER=external.postgres.example/POSTGRES_SERVER=postgresql/' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    [[ "$OAUTH" != true ]] || prepare_oc_direct_fixture
    local output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n' bash -x ./scripts/oc-deploy.sh || { sed -n '1,260p' "$output" >&2; fail 'OpenShift success case failed'; }
    assert_absent "$STATE/calls.log" ENV_LEAK
    assert_contains "$STATE/manifests.log" 'app.kubernetes.io/instance: app-a'
    assert_contains "$STATE/manifests.log" 'app.kubernetes.io/managed-by: cen-template'
    assert_contains "$output" "Resolved source branch: $FLAVOR"
    assert_contains "$STATE/calls.log" "git ls-remote --exit-code --heads git@github.com:owner/repository.git refs/heads/$FLAVOR"
    assert_contains "$STATE/manifests.log" "ref: \"$FLAVOR\""
    assert_contains "$STATE/manifests.log" 'name: webhook-access-unauthenticated'
    assert_contains "$STATE/manifests.log" 'name: system:webhook'
    assert_contains "$STATE/manifests.log" 'name: system:unauthenticated'
    assert_contains "$STATE/calls.log" 'oc auth can-i create rolebindings.rbac.authorization.k8s.io --namespace mock-project'
    assert_contains "$STATE/calls.log" 'oc auth can-i bind clusterroles.rbac.authorization.k8s.io/system:webhook --namespace mock-project'
    assert_absent "$STATE/secrets/app-a-env.env" GITHUB_TOKEN
    assert_absent "$STATE/secrets/app-a-env.env" IAM_API_KEY
    assert_absent "$STATE/secrets/app-a-env.env" OAUTH2_PROXY_CLIENT_SECRET
    assert_contains "$STATE/secrets/app-a-env.env" 'BACKEND_CORS_ORIGINS=https://admin.example.com'
    if [[ "$HAS_FRONTEND" == true && "$OAUTH" != true ]]; then assert_contains "$STATE/secrets/app-a-env.env" 'frontend-mock-project.apps.mock.example'; fi
    if [[ "$OAUTH" == true ]]; then assert_contains "$STATE/secrets/app-a-env.env" 'oauth-proxy-mock-project.apps.mock.example'; fi
    if [[ "$HAS_FRONTEND" != true ]]; then assert_absent "$STATE/secrets/app-a-env.env" 'BACKEND_CORS_ORIGINS=*'; fi
    if [[ "$HAS_FRONTEND" == true ]]; then assert_contains "$STATE/manifests.log" 'name: frontend'; else assert_absent "$STATE/manifests.log" 'name: frontend'; fi
    if [[ "$HAS_DATABASE" == true ]]; then assert_contains "$STATE/manifests.log" 'kind: PersistentVolumeClaim'; else assert_absent "$STATE/manifests.log" 'kind: PersistentVolumeClaim'; fi
    if [[ "$OAUTH" == true ]]; then
        assert_before "$STATE/calls.log" 'rollout status deployment/oauth-proxy --timeout=15m' 'MOCK_EVENT oauth-ingress-switched'
        assert_before "$STATE/calls.log" 'MOCK_EVENT oauth-ingress-switched' 'delete route/weighted-direct --ignore-not-found'
        assert_contains "$STATE/manifests.log" 'oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561'
        assert_contains "$STATE/manifests.log" '--cookie-secure=true'
        assert_contains "$output" 'OAuth redirect URL: https://oauth-proxy-mock-project.apps.mock.example/oauth2/callback'
        [[ -f "$STATE/direct-deleted" ]] || fail 'owned direct route was not removed'
    fi
    assert_contains "$output" 'GitHub webhooks configured automatically: true'
    if [[ "$OAUTH" != true ]]; then assert_contains "$output" 'Backend: https://backend-mock-project.apps.mock.example'; fi
    if [[ "$HAS_FRONTEND" == true && "$OAUTH" != true ]]; then assert_contains "$output" 'Frontend: https://frontend-mock-project.apps.mock.example'; fi
    assert_no_secret_leak "$output"; assert_no_secret_leak "$STATE/calls.log"; assert_temp_cleanup
    pass "OpenShift $FLAVOR multi-image topology and stateful ownership reconciliation"
}

run_oc_collision() {
    prepare_case oc-isolation
    put_resource "$STATE" deployment backend app-b
    local output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' ./scripts/oc-deploy.sh; then fail 'OpenShift mutated an app-b collision'; fi
    assert_contains "$output" 'deployment/backend exists but is not owned by this deployment'
    assert_absent "$STATE/calls.log" 'rollout status -n openshift-image-registry'
    assert_absent "$STATE/calls.log" 'delete deployment/backend'
    pass 'OpenShift app-a refuses app-b at the expected name'
}

run_oc_unowned_direct() {
    [[ "$OAUTH" == true ]] || return 0
    prepare_case oc-unowned-direct
    prepare_oc_direct_fixture; touch "$STATE/direct-unowned"; put_resource "$STATE" route weighted-direct app-b
    local output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' ./scripts/oc-deploy.sh; then fail 'OpenShift accepted unowned direct ingress'; fi
    assert_contains "$output" 'route/weighted-direct exists but is not owned by this deployment'
    assert_absent "$STATE/calls.log" 'rollout status -n openshift-image-registry'
    assert_absent "$STATE/calls.log" 'MOCK_EVENT oauth-ingress-switched'
    pass 'OpenShift OAuth preflight leaves unowned direct ingress untouched'
}

run_oc_confirmation_and_reset() {
    prepare_case oc-confirmation
    local output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'wrong\n' ./scripts/oc-deploy.sh; then fail 'OpenShift accepted wrong target confirmation'; fi
    assert_absent "$STATE/calls.log" 'project mock-project'
    if [[ "$HAS_DATABASE" == true ]]; then
        prepare_case oc-reset
        sed -i.bak 's/POSTGRES_SERVER=external.postgres.example/POSTGRES_SERVER=postgresql/' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
        put_resource "$STATE" deployment postgresql app-a; put_resource "$STATE" service postgresql app-a; put_resource "$STATE" pvc postgresql-data app-a
        output="$CASE_DIR/output.log"
        if run_with_mocks "$output" 'mock-project\nwrong\n' ./scripts/oc-deploy.sh --reset-prod-db; then fail 'database reset accepted wrong destructive confirmation'; fi
        assert_absent "$STATE/calls.log" 'delete pvc/postgresql-data'
    fi
    pass 'OpenShift target and destructive reset confirmations are enforced'
}

run_oc_branch_ref_cases() {
    prepare_case oc-missing-branch
    sed -i.bak 's/^_DEPLOYMENT_BRANCH_FILTER=.*/_DEPLOYMENT_BRANCH_FILTER=does-not-exist/' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    local output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' ./scripts/oc-deploy.sh; then fail 'OpenShift accepted a nonexistent source branch'; fi
    assert_contains "$output" "source branch 'does-not-exist' does not resolve"
    assert_absent "$STATE/manifests.log" 'kind: BuildConfig'
    pass 'OpenShift defaults to the flavor ref and refuses a nonexistent configured ref before BuildConfig creation'
}

run_oc_webhook_cases() {
    prepare_case oc-webhook-rbac-denied
    local output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n' env MOCK_WEBHOOK_RBAC_DENIED=true ./scripts/oc-deploy.sh || {
        sed -n '1,260p' "$output" >&2; fail 'OpenShift failed deployment after webhook RoleBinding permission denial'
    }
    local webhook_secret
    webhook_secret=$(<"$STATE/secrets/github-webhook-secret.WebHookSecretKey")
    assert_contains "$output" 'Cannot configure OpenShift webhooks: current user cannot bind ClusterRole system:webhook in this project.'
    assert_contains "$output" "oc -n mock-project apply -f - <<'EOF'"
    assert_contains "$output" 'app.kubernetes.io/managed-by: cen-template'
    assert_contains "$output" 'app.kubernetes.io/instance: app-a'
    assert_contains "$output" 'Until this RoleBinding exists, GitHub pushes will not trigger OpenShift builds.'
    assert_contains "$output" 'GitHub webhooks active: false (current user cannot bind ClusterRole system:webhook in this project)'
    assert_contains "$output" 'Deployment completed successfully.'
    assert_contains "$STATE/terminal.log" "webhooks/$webhook_secret/github"
    assert_absent "$output" "$webhook_secret"
    assert_absent "$STATE/calls.log" '/hooks'
    assert_absent "$STATE/manifests.log" 'kind: RoleBinding'

    prepare_case oc-webhook-rbac-forbidden-fallback
    output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n' env MOCK_WEBHOOK_RBAC_APPLY_FAILURE=forbidden ./scripts/oc-deploy.sh || {
        sed -n '1,260p' "$output" >&2; fail 'OpenShift failed deployment after fallback-classified RoleBinding denial'
    }
    assert_contains "$output" 'OpenShift rejected the RoleBinding as forbidden'
    assert_contains "$output" 'GitHub webhooks active: false (OpenShift rejected the RoleBinding as forbidden)'
    assert_contains "$output" 'Deployment completed successfully.'
    assert_absent "$STATE/calls.log" '/hooks'

    prepare_case oc-webhook-rbac-apply-failure
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' env MOCK_WEBHOOK_RBAC_APPLY_FAILURE=invalid ./scripts/oc-deploy.sh; then
        fail 'OpenShift ignored a genuine webhook RoleBinding apply failure'
    fi
    assert_contains "$output" 'error parsing STDIN: error converting YAML to JSON'
    assert_absent "$output" 'Deployment completed successfully.'

    prepare_case oc-webhook-failure
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' env MOCK_WEBHOOK_POST_FAIL=true ./scripts/oc-deploy.sh; then
        sed -n '1,220p' "$output" >&2; sed -n '1,260p' "$STATE/calls.log" >&2
        fail 'OpenShift ignored GitHub webhook POST failure'
    fi
    assert_contains "$output" 'GitHub webhook creation failed for backend (HTTP 500)'
    assert_absent "$output" 'Deployment completed successfully.'

    prepare_case oc-webhook-manual
    sed -i.bak '/^_GITHUB_TOKEN=/d; /^GITHUB_TOKEN=/d' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n\n' ./scripts/oc-deploy.sh || { sed -n '1,240p' "$output" >&2; fail 'manual webhook deployment failed'; }
    webhook_secret=$(<"$STATE/secrets/github-webhook-secret.WebHookSecretKey")
    assert_contains "$STATE/terminal.log" "webhooks/$webhook_secret/github"
    assert_absent "$output" "$webhook_secret"
    assert_contains "$output" 'GitHub webhooks configured automatically: false'
    pass 'webhook RBAC permission fallback, genuine failures, POST failures, and terminal-only URLs are enforced'
}

prepare_legacy_fixture() {
    local resource
    for resource in buildconfig/backend deployment/backend service/backend secret/git-secret "secret/app-a-env"; do
        put_legacy_resource "$STATE" "${resource%%/*}" "${resource#*/}"
    done
    if [[ "$HAS_FRONTEND" == true ]]; then
        for resource in buildconfig/frontend deployment/frontend service/frontend; do
            put_legacy_resource "$STATE" "${resource%%/*}" "${resource#*/}"
        done
    fi
}

run_oc_adoption_cases() {
    local output
    prepare_case oc-adoption-opt-in
    prepare_legacy_fixture
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' ./scripts/oc-deploy.sh; then fail 'legacy resources were adopted without the explicit flag'; fi
    assert_contains "$output" 'exists but is not owned by this deployment'
    assert_absent "$STATE/calls.log" 'oc label buildconfig/backend'

    prepare_case oc-adoption-success
    prepare_legacy_fixture
    output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\nadopt mock-project/app-a\n' ./scripts/oc-deploy.sh --adopt-legacy-resources || {
        sed -n '1,240p' "$output" >&2; fail 'verified legacy adoption failed';
    }
    assert_contains "$output" 'Adopted buildconfig/backend'
    assert_contains "$STATE/calls.log" 'oc label buildconfig/backend app.kubernetes.io/managed-by=cen-template app.kubernetes.io/instance=app-a --overwrite'

    prepare_case oc-adoption-ambiguous
    prepare_legacy_fixture
    node -e 'const fs=require("node:fs"),p=process.argv[1],x=JSON.parse(fs.readFileSync(p));x.spec.ports[0].port=9999;fs.writeFileSync(p,JSON.stringify(x))' \
        "$STATE/json/service__backend.json"
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\nadopt mock-project/app-a\n' ./scripts/oc-deploy.sh --adopt-legacy-resources; then fail 'ambiguous legacy service was adopted'; fi
    assert_contains "$output" 'service/backend is ambiguous or does not match this application'
    assert_absent "$STATE/calls.log" 'oc label buildconfig/backend'
    pass 'legacy adoption is explicit, exact, inspect-first, and ambiguity-refusing'
}

run_postgres_credential_cases() {
    [[ "$HAS_DATABASE" == true ]] || return 0
    local output
    prepare_case oc-db-credential-decline
    sed -i.bak 's/POSTGRES_SERVER=external.postgres.example/POSTGRES_SERVER=postgresql/' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    put_resource "$STATE" deployment postgresql app-a; put_resource "$STATE" service postgresql app-a; put_resource "$STATE" pvc postgresql-data app-a
    printf 'app' > "$STATE/postgres-POSTGRES_DB"; printf 'app' > "$STATE/postgres-POSTGRES_USER"; printf 'old-database-secret' > "$STATE/postgres-POSTGRES_PASSWORD"
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\nwrong\n' ./scripts/oc-deploy.sh; then fail 'PostgreSQL credential drift continued without typed reset confirmation'; fi
    assert_contains "$output" 'Running PostgreSQL credentials differ for: POSTGRES_PASSWORD'
    assert_absent "$STATE/calls.log" 'create secret generic app-a-env'
    assert_absent "$STATE/calls.log" 'delete pvc/postgresql-data'

    prepare_case oc-db-credential-confirm
    sed -i.bak 's/POSTGRES_SERVER=external.postgres.example/POSTGRES_SERVER=postgresql/' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    put_resource "$STATE" deployment postgresql app-a; put_resource "$STATE" service postgresql app-a; put_resource "$STATE" pvc postgresql-data app-a
    printf 'app' > "$STATE/postgres-POSTGRES_DB"; printf 'app' > "$STATE/postgres-POSTGRES_USER"; printf 'old-database-secret' > "$STATE/postgres-POSTGRES_PASSWORD"
    output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\nmock-project\n' ./scripts/oc-deploy.sh || fail 'confirmed PostgreSQL credential reset failed'
    assert_contains "$STATE/calls.log" 'delete pvc/postgresql-data --ignore-not-found'
    pass 'running PostgreSQL credential drift is detected before secret replacement and requires typed destructive confirmation'
}

run_ce_preflight_cases() {
    [[ "$HAS_FRONTEND" == true ]] || return 0
    local output
    prepare_case ce-nginx-preflight
    sed -i.bak '/ARG VITE_API_URL/d' "$PROJECT/frontend/Dockerfile"; rm -f "$PROJECT/frontend/Dockerfile.bak"
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' ./scripts/ce-deploy.sh; then fail 'CE accepted OpenShift nginx fallback without VITE_API_URL support'; fi
    assert_contains "$output" 'nginx /api targets the OpenShift-only backend service'
    assert_absent "$STATE/calls.log" 'ibmcloud target'

    prepare_case ce-vite-preflight
    printf '\nVITE_UNDECLARED=value\n' >> "$PROJECT/.env.production"
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' ./scripts/ce-deploy.sh; then fail 'CE accepted a Vite variable missing from Dockerfile'; fi
    assert_contains "$output" 'VITE_UNDECLARED is deployed as a Code Engine build argument but is missing as ARG'
    assert_absent "$STATE/calls.log" 'ibmcloud target'
    pass 'Code Engine nginx and Dockerfile/Vite mismatches fail before cloud mutation'
}

run_ce_registry_and_project_cases() {
    local output
    prepare_case ce-registry-reuse
    put_resource "$STATE" secret mock-project-registry-secret app-a; touch "$STATE/registries/mock-project-registry-secret"
    sed -i.bak '/^_IAM_API_KEY=/d' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    if [[ "$OAUTH" == true ]]; then
        put_resource "$STATE" services.serving.knative.dev mock-project-backend app-a
        put_resource "$STATE" services.serving.knative.dev mock-project-frontend app-a
    fi
    output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n' ./scripts/ce-deploy.sh || fail 'CE could not reuse an owned registry secret without IAM key'
    assert_absent "$STATE/calls.log" 'ce registry delete'
    assert_absent "$STATE/calls.log" 'ce registry create'

    prepare_case ce-project-readiness
    output="$CASE_DIR/output.log"
    if [[ "$OAUTH" == true ]]; then
        if run_with_mocks "$output" 'mock-project\n' env MOCK_CE_PROJECT_ABSENT=true ./scripts/ce-deploy.sh; then fail 'OAuth CE created a project despite the fail-closed existing-project rule'; fi
        assert_contains "$output" 'OAuth deployment requires an existing readable Code Engine project'
        assert_absent "$STATE/calls.log" 'ce project create'
    else
        run_with_mocks "$output" 'mock-project\n' env MOCK_CE_PROJECT_ABSENT=true ./scripts/ce-deploy.sh || fail 'fresh CE project readiness flow failed'
        assert_before "$STATE/calls.log" 'ce project create --name mock-project' 'ce project select --name mock-project --kubecfg'
        assert_contains "$output" "Code Engine project 'mock-project' is ready."
    fi
    pass 'owned CE registry secrets are reusable and fresh-project readiness is gated without weakening OAuth project visibility'
}

run_oauth_secret_cases() {
    [[ "$OAUTH" == true ]] || return 0
    local output generated
    prepare_case ce-oauth-seam-generate
    sed -i.bak 's|^OAUTH2_PROXY_UPSTREAM_PASSWORD=.*|OAUTH2_PROXY_UPSTREAM_PASSWORD=<generate-a-random-upstream-password>|' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    put_resource "$STATE" secret mock-project-registry-secret app-a; touch "$STATE/registries/mock-project-registry-secret"
    put_resource "$STATE" services.serving.knative.dev mock-project-backend app-a; put_resource "$STATE" services.serving.knative.dev mock-project-frontend app-a
    output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n' ./scripts/ce-deploy.sh || fail 'CE OAuth seam marker generation failed'
    generated=$(sed -n 's/^OAUTH2_PROXY_UPSTREAM_PASSWORD=//p' "$STATE/secrets/mock-project-backend-config.env")
    [[ ${#generated} -ge 32 && "$generated" != \<*\> ]] || fail 'CE did not replace the OAuth seam marker with a strong value'
    assert_absent "$STATE/calls.log" '<generate-a-random-upstream-password>'

    prepare_case ce-oauth-seam-placeholder
    sed -i.bak 's|^OAUTH2_PROXY_UPSTREAM_PASSWORD=.*|OAUTH2_PROXY_UPSTREAM_PASSWORD=<placeholder-secret-that-is-long-enough>|' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" '' ./scripts/ce-deploy.sh; then fail 'CE accepted an arbitrary OAuth seam placeholder'; fi
    assert_contains "$output" 'must be a non-placeholder random value of at least 32 characters'
    assert_absent "$STATE/calls.log" 'ibmcloud target'
    pass 'Code Engine generates the documented OAuth seam marker and refuses other placeholders before cloud work'
}

run_validation_case() {
    local name=$1 edit=$2 expected=$3 output
    prepare_case "validation-$name"
    sed -i.bak "$edit" "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" '' ./scripts/oc-deploy.sh; then fail "validation case $name unexpectedly passed"; fi
    assert_contains "$output" "$expected"
    assert_absent "$STATE/calls.log" 'oc whoami'
}

run_validation_cases() {
    run_validation_case project 's/^PROJECT_NAME=.*/PROJECT_NAME=Invalid_Name/' 'PROJECT_NAME must be a lowercase DNS label'
    run_validation_case git-url 's|^_GIT_SSH_URL=.*|_GIT_SSH_URL=https://github.com/owner/repository|' 'unsupported SSH Git URL'
    if [[ "$HAS_DATABASE" == true ]]; then run_validation_case postgres-password 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=short/' 'POSTGRES_PASSWORD must be at least 8 characters'; fi
    case "$FLAVOR" in
        local-auth|local-auth-custom-ui)
            run_validation_case email 's/^FIRST_SUPERUSER=.*/FIRST_SUPERUSER=invalid/' 'FIRST_SUPERUSER is not a valid email address'
            run_validation_case superuser-password 's/^FIRST_SUPERUSER_PASSWORD=.*/FIRST_SUPERUSER_PASSWORD=short/' 'FIRST_SUPERUSER_PASSWORD must be at least 8 characters'
            run_validation_case signup-password 's/^SECRET_KEY=.*/SIGNUP_ACCESS_PASSWORD=short\nSECRET_KEY=application-secret-value-0123456789abcdef/' 'SIGNUP_ACCESS_PASSWORD must be at least 8 characters'
            run_validation_case secret-key 's/^SECRET_KEY=.*/SECRET_KEY=short-secret/' 'SECRET_KEY must be at least 32 characters'
            ;;
        backend-only|backend-only-no-db) run_validation_case api-key 's/^API_KEY=.*/API_KEY=too-short/' 'API_KEY length must be one of' ;;
        oauth-proxy|oauth-proxy-custom-ui) run_validation_case oauth-cookie 's/^OAUTH2_PROXY_COOKIE_SECRET=.*/OAUTH2_PROXY_COOKIE_SECRET=short/' 'OAUTH2_PROXY_COOKIE_SECRET must be at least 16 characters' ;;
    esac

    prepare_case validation-ce-project
    sed -i.bak 's/^_CE_PROJECT_NAME=.*/_CE_PROJECT_NAME=this-project-name-is-too-long/' "$PROJECT/.env.production"; rm -f "$PROJECT/.env.production.bak"
    local output="$CASE_DIR/output.log"
    if run_with_mocks "$output" '' ./scripts/ce-deploy.sh; then fail 'CE accepted an overlong project name'; fi
    assert_contains "$output" '_CE_PROJECT_NAME must be a lowercase DNS label of at most 20 characters'
    assert_absent "$STATE/calls.log" 'ibmcloud account show'
    pass 'restored name, Git URL, email, API-key, password, and OAuth cookie validations run before cluster mutation'
}

run_registry_permission_cases() {
    local output
    prepare_case oc-registry-permission
    output="$CASE_DIR/output.log"
    run_with_mocks "$output" 'mock-project\n' env MOCK_REGISTRY_READ_DENIED=true ./scripts/oc-deploy.sh || fail 'project-scoped OpenShift user was blocked only by registry read permissions'
    assert_contains "$output" 'continuing without the readiness gate'

    prepare_case oc-registry-unready
    output="$CASE_DIR/output.log"
    if run_with_mocks "$output" 'mock-project\n' env MOCK_REGISTRY_UNREADY=true ./scripts/oc-deploy.sh; then fail 'genuinely unready OpenShift registry was ignored'; fi
    assert_contains "$output" 'integrated registry is not managed with configured storage'
    assert_absent "$STATE/manifests.log" 'kind: BuildConfig'
    pass 'registry read denial warns and continues while genuine readable unreadiness still fails'
}

run_show_env_values_case() {
    prepare_case show-env-values
    local output="$CASE_DIR/output.log"
    (
        source "$PROJECT/scripts/lib/00-common.sh"
        DEPLOY_MOCK=true
        CEN_DEPLOY_FLAVOR=$FLAVOR
        CEN_DEPLOY_TERMINAL_FILE="$STATE/terminal.log"
        load_env_file "$PROJECT/.env.production" true
    ) > "$output" 2>&1
    assert_contains "$STATE/terminal.log" 'POSTGRES_PASSWORD=database-secret-value'
    assert_absent "$output" 'database-secret-value'
    pass '--show-env-values restores explicit terminal-only values without adding them to captured output'
}

run_predicate_unit() {
    (
        source "$ROOT/scripts/lib/00-common.sh"
        APP_NAME=app-a
        resource_is_owned_by_this_deployment cen-template app-a
        ! resource_is_owned_by_this_deployment cen-template app-b
        ! resource_is_owned_by_this_deployment other app-a
    ) || fail 'two-label ownership predicate unit failed'
    pass 'exact two-label predicate rejects managed-only and wrong-instance resources'
}

run_ce_success
run_ce_success podman
run_ce_collision
run_ce_confirmation
run_ce_preflight_cases
run_ce_registry_and_project_cases
run_oauth_secret_cases
run_oc_success
run_oc_collision
run_oc_unowned_direct
run_oc_confirmation_and_reset
run_oc_branch_ref_cases
run_oc_webhook_cases
run_oc_adoption_cases
run_postgres_credential_cases
run_validation_cases
run_registry_permission_cases
run_show_env_values_case
run_predicate_unit
printf '\nAll deploy mock cases passed for %s.\n' "$FLAVOR"
