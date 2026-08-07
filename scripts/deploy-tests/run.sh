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
API_KEY=api-key-value-0123456789abcdef
POSTGRES_SERVER=external.postgres.example
POSTGRES_PORT=5432
POSTGRES_DB=app
POSTGRES_USER=app
POSTGRES_PASSWORD=database-secret-value
BACKEND_CORS_ORIGINS=
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
_DEPLOYMENT_BRANCH_FILTER=main
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

make_mocks() {
    local bin=$1
    mkdir -p "$bin"; : > "$bin/.cen-deploy-mock-bin"
    cat > "$bin/docker" <<'EOF'
#!/usr/bin/env bash
# cen-deploy-mock-command
if env | grep -Eq '^(GITHUB_TOKEN|IAM_API_KEY|POSTGRES_PASSWORD|OAUTH2_PROXY_CLIENT_SECRET|OAUTH2_PROXY_COOKIE_SECRET|OAUTH2_PROXY_UPSTREAM_PASSWORD)='; then printf 'ENV_LEAK docker\n' >> "$MOCK_LOG"; fi
printf 'docker' >> "$MOCK_LOG"; printf ' %q' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
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
if [[ "$args" == *' ce project get '* || "$args" == *' plugin show '* ]]; then exit 0; fi
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
previous=''; args=" $* "
for argument in "$@"; do
  [[ "$previous" != --config ]] || printf '%s\n' "$argument" >> "$MOCK_TEMP_FILES"
  [[ "$argument" != @* ]] || printf '%s\n' "${argument#@}" >> "$MOCK_TEMP_FILES"
  previous=$argument
done
if [[ "$args" == *'/keys '* ]]; then printf '[{"id":1,"key":"ssh-ed25519 AAAATEST mock"}]'; exit 0; fi
if [[ "$args" == *'/hooks '* ]]; then if [[ "$args" == *' --request POST '* ]]; then printf '{}\n201'; else printf '[]\n200'; fi; fi
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
if [[ "$args" == *' get ingress.config.openshift.io cluster '* ]]; then printf 'apps.mock.example'; exit 0; fi
if [[ "$args" == *' get configs.imageregistry.operator.openshift.io cluster '*'.spec.managementState'* ]]; then printf 'Managed'; exit 0; fi
if [[ "$args" == *' get configs.imageregistry.operator.openshift.io cluster '*'.spec.storage'* ]]; then printf '{"emptyDir":{}}'; exit 0; fi
if [[ "$args" == *' get endpoints image-registry '* ]]; then printf '10.0.0.1'; exit 0; fi
if [[ "$args" == *' registry info '* ]]; then printf 'registry.mock'; exit 0; fi
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
  if [[ "$input" == *'name: oauth-proxy'* && "$input" == *'kind: Route'* ]]; then printf 'MOCK_EVENT oauth-ingress-switched\n' >> "$MOCK_LOG"; fi
  while IFS='|' read -r kind name; do
    case "$kind" in PersistentVolumeClaim) kind=pvc ;; Deployment) kind=deployment ;; Service) kind=service ;; Route) kind=route ;; BuildConfig) kind=buildconfig ;; ImageStream) kind=imagestream ;; Secret) kind=secret ;; esac
    [[ -z "$kind" || -z "$name" ]] || printf 'cen-template|app-a\n' > "$(resource_file "$kind" "$name")"
  done < <(printf '%s\n' "$input" | awk '/^kind: /{k=$2;n=""} /^  name: / && n==""{n=$2;print k "|" n}')
  exit 0
fi
if [[ "${1:-}" == get ]]; then
  kind=${2:-}; name=${3:-}; file=$(resource_file "$kind" "$name")
  if [[ "$kind" == project && "$name" == mock-project ]]; then exit 0; fi
  if [[ "$kind" == route && "$args" == *'.spec.host'* && -f "$file" ]]; then printf '%s-mock-project.apps.mock.example' "$name"; exit 0; fi
  [[ -f "$file" ]] || exit 1
  IFS='|' read -r managed instance < "$file"
  if [[ "$args" == *'managed-by'* ]]; then printf '%s' "$managed"; fi
  if [[ "$args" == *'instance'* ]]; then printf '%s' "$instance"; fi
  if [[ "$kind" == secret && "$args" == *'.data.'* ]]; then
    key=${args##*.data.}; key=${key%%\}*}; [[ -f "$MOCK_SECRETS/$name.$key" ]] || exit 1; base64 < "$MOCK_SECRETS/$name.$key" | tr -d '\n'
  fi
  exit 0
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
    mkdir -p "$STATE/resources" "$STATE/registries" "$STATE/secrets" "$STATE/ssh" "$PROJECT"
    cp -R "$ROOT/scripts" "$PROJECT/scripts"
    make_env "$PROJECT/.env.production"
    printf 'private\n' > "$STATE/ssh/ocp-key"
    printf 'ssh-ed25519 AAAATEST mock\n' > "$STATE/ssh/ocp-key.pub"
    : > "$STATE/calls.log"; : > "$STATE/manifests.log"; : > "$STATE/temp-files.log"
    make_mocks "$STATE/bin"
}

run_with_mocks() {
    local output=$1 input=$2; shift 2
    printf '%b' "$input" | (
        cd "$PROJECT"
        PATH="$STATE/bin:$PATH" MOCK_LOG="$STATE/calls.log" MOCK_MANIFESTS="$STATE/manifests.log" \
        MOCK_TEMP_FILES="$STATE/temp-files.log" MOCK_SECRETS="$STATE/secrets" MOCK_STATE="$STATE" \
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
    prepare_case ce-success
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
    if [[ "$HAS_FRONTEND" == true ]]; then [[ $(grep -Fc 'docker image build' "$STATE/calls.log") == 2 ]] || fail 'expected two Code Engine images';
    else [[ $(grep -Fc 'docker image build' "$STATE/calls.log") == 1 ]] || fail 'expected one Code Engine image'; fi
    if [[ "$OAUTH" == true ]]; then
        assert_before "$STATE/calls.log" 'ce application update --name mock-project-backend --visibility project' 'cr login'
        assert_before "$STATE/calls.log" 'ce application update --name mock-project-frontend --visibility project' 'docker image build'
        assert_contains "$STATE/calls.log" 'oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561'
        assert_contains "$STATE/calls.log" '--argument=--cookie-secure=true'
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
    assert_absent "$STATE/secrets/app-a-env.env" GITHUB_TOKEN
    assert_absent "$STATE/secrets/app-a-env.env" IAM_API_KEY
    assert_absent "$STATE/secrets/app-a-env.env" OAUTH2_PROXY_CLIENT_SECRET
    if [[ "$HAS_FRONTEND" == true ]]; then assert_contains "$STATE/manifests.log" 'name: frontend'; else assert_absent "$STATE/manifests.log" 'name: frontend'; fi
    if [[ "$HAS_DATABASE" == true ]]; then assert_contains "$STATE/manifests.log" 'kind: PersistentVolumeClaim'; else assert_absent "$STATE/manifests.log" 'kind: PersistentVolumeClaim'; fi
    if [[ "$OAUTH" == true ]]; then
        assert_before "$STATE/calls.log" 'rollout status deployment/oauth-proxy --timeout=15m' 'MOCK_EVENT oauth-ingress-switched'
        assert_before "$STATE/calls.log" 'MOCK_EVENT oauth-ingress-switched' 'delete route/weighted-direct --ignore-not-found'
        assert_contains "$STATE/manifests.log" 'oauth2-proxy:v7.15.3@sha256:10a1165743a192e1940b4708fb9647027185ce11a681a1c5519b442ff7f1f561'
        assert_contains "$STATE/manifests.log" '--cookie-secure=true'
        [[ -f "$STATE/direct-deleted" ]] || fail 'owned direct route was not removed'
    fi
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
run_ce_collision
run_ce_confirmation
run_oc_success
run_oc_collision
run_oc_unowned_direct
run_oc_confirmation_and_reset
run_predicate_unit
printf '\nAll deploy mock cases passed for %s.\n' "$FLAVOR"
