#!/usr/bin/env bash

git_repo_parts() {
    local url=$1 host_without_prefix
    if [[ "$url" =~ ^git@([^:]+):([^/]+)/(.+)\.git$ ]]; then
        GIT_HOST=${BASH_REMATCH[1]}; GIT_OWNER=${BASH_REMATCH[2]}; GIT_REPO=${BASH_REMATCH[3]}
    elif [[ "$url" =~ ^ssh://git@([^/]+)/([^/]+)/(.+)\.git$ ]]; then
        GIT_HOST=${BASH_REMATCH[1]}; GIT_OWNER=${BASH_REMATCH[2]}; GIT_REPO=${BASH_REMATCH[3]}
    else
        print_error "unsupported SSH Git URL: $url"
        return 1
    fi
    host_without_prefix=${GIT_HOST#github.}
    if [[ "$GIT_HOST" == github.com ]]; then GITHUB_API_BASE=https://api.github.com
    elif [[ "$host_without_prefix" != "$GIT_HOST" ]]; then GITHUB_API_BASE="https://api.${GIT_HOST}"
    else GITHUB_API_BASE="https://${GIT_HOST}/api/v3"
    fi
    GITHUB_REPO_API="${GITHUB_API_BASE}/repos/${GIT_OWNER}/${GIT_REPO}"
}

resolve_deployment_branch_ref() {
    DEPLOYMENT_BRANCH_FILTER=${_DEPLOYMENT_BRANCH_FILTER:-${DEPLOYMENT_BRANCH_FILTER:-}}
    [[ -n "$DEPLOYMENT_BRANCH_FILTER" ]] || DEPLOYMENT_BRANCH_FILTER=$CEN_DEPLOY_FLAVOR
    if [[ "$DEPLOYMENT_BRANCH_FILTER" == -* || "$DEPLOYMENT_BRANCH_FILTER" == *'..'* || \
        "$DEPLOYMENT_BRANCH_FILTER" == *'~'* || "$DEPLOYMENT_BRANCH_FILTER" == *'^'* || \
        "$DEPLOYMENT_BRANCH_FILTER" == *':'* || "$DEPLOYMENT_BRANCH_FILTER" == *' '* || \
        "$DEPLOYMENT_BRANCH_FILTER" == */ || "$DEPLOYMENT_BRANCH_FILTER" == .* ]]; then
        print_error "invalid deployment branch ref: $DEPLOYMENT_BRANCH_FILTER"
        return 1
    fi
    print_status "Resolved source branch: $DEPLOYMENT_BRANCH_FILTER"
    add_deployment_output source_branch "$DEPLOYMENT_BRANCH_FILTER"
}

validate_remote_branch_ref() {
    local key_dir=${CEN_DEPLOY_SSH_DIR:-"$HOME/.ssh/$PROJECT_NAME"}
    local key_file="$key_dir/ocp-key" output
    [[ -f "$key_file" ]] || { print_error "cannot validate source branch without deploy key: $key_file"; return 1; }
    if ! output=$(GIT_SSH_COMMAND="ssh -i $key_file -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
        git ls-remote --exit-code --heads "$GIT_SSH_URL" "refs/heads/$DEPLOYMENT_BRANCH_FILTER" 2>&1); then
        print_error "source branch '$DEPLOYMENT_BRANCH_FILTER' does not resolve in $GIT_SSH_URL"
        [[ -z "$output" ]] || printf '%s\n' "$output" >&2
        return 1
    fi
    [[ -n "$output" ]] || {
        print_error "source branch '$DEPLOYMENT_BRANCH_FILTER' does not resolve in $GIT_SSH_URL"
        return 1
    }
    print_success "Verified source branch '$DEPLOYMENT_BRANCH_FILTER' in the configured repository."
}

make_github_curl_config() {
    local destination=$1 token=${GITHUB_TOKEN:-}
    [[ -n "$token" ]] || return 1
    if [[ "$token" == *$'\n'* || "$token" == *$'\r'* || "$token" == *'"'* ]]; then
        print_error 'GITHUB_TOKEN contains unsupported characters'
        return 1
    fi
    make_temp_file "$destination"
    printf 'header = "Authorization: Bearer %s"\n' "$token" > "${!destination}"
}

github_deploy_key_present() {
    local fingerprint=$1 response curl_config
    make_github_curl_config curl_config || return 1
    response=$(curl --disable --config "$curl_config" --fail --silent --show-error --url "$GITHUB_REPO_API/keys" || true)
    printf '%s' "$response" | grep -Fq "$fingerprint"
}

add_github_deploy_key() {
    local public_key=$1 curl_config payload_file
    make_github_curl_config curl_config || return 1
    make_temp_file payload_file
    node -e 'const fs=require("node:fs"); fs.writeFileSync(process.argv[1], JSON.stringify({title:`OpenShift deploy key - ${process.argv[2]}`,key:process.argv[3],read_only:true}))' \
        "$payload_file" "$PROJECT_NAME" "$public_key"
    curl --disable --config "$curl_config" --fail --silent --show-error --request POST \
        --header 'Accept: application/vnd.github+json' --url "$GITHUB_REPO_API/keys" \
        --data-binary "@$payload_file" >/dev/null
}

delete_ssh_keys() {
    local key_dir=${CEN_DEPLOY_SSH_DIR:-"$HOME/.ssh/$PROJECT_NAME"}
    local public_file="$key_dir/ocp-key.pub" fingerprint response key_id curl_config
    [[ -n "$key_dir" && "$key_dir" != / && "$key_dir" != "$HOME" ]] || { print_error 'refusing unsafe SSH key directory'; return 1; }
    if [[ -f "$public_file" && -n "${GITHUB_TOKEN:-}" ]]; then
        git_repo_parts "$GIT_SSH_URL"
        fingerprint=$(awk '{print $2}' "$public_file")
        make_github_curl_config curl_config
        response=$(curl --disable --config "$curl_config" --fail --silent --show-error --url "$GITHUB_REPO_API/keys" || true)
        key_id=$(printf '%s' "$response" | node -e 'let b="";process.stdin.on("data",c=>b+=c);process.stdin.on("end",()=>{const m=JSON.parse(b||"[]").find(x=>x.key?.includes(process.argv[1]));if(m)process.stdout.write(String(m.id))})' "$fingerprint" || true)
        if [[ -n "$key_id" ]]; then
            print_warning "Deleting owned local deploy-key association from GitHub (key id $key_id)"
            curl --disable --config "$curl_config" --fail --silent --show-error --request DELETE --url "$GITHUB_REPO_API/keys/$key_id" >/dev/null || return 1
        fi
    fi
    rm -f -- "$key_dir/ocp-key" "$key_dir/ocp-key.pub"
    delete_owned_oc_resource secret git-secret
}

setup_ssh_keys() {
    local key_dir=${CEN_DEPLOY_SSH_DIR:-"$HOME/.ssh/$PROJECT_NAME"}
    local key_file="$key_dir/ocp-key" public_file="$key_dir/ocp-key.pub" public_key fingerprint
    git_repo_parts "$GIT_SSH_URL"
    mkdir -p "$key_dir"; chmod 700 "$key_dir"
    if [[ ! -f "$key_file" || ! -f "$public_file" ]]; then
        need_command ssh-keygen
        ssh-keygen -q -t ed25519 -N '' -C "openshift-${PROJECT_NAME}" -f "$key_file"
    fi
    public_key=$(<"$public_file")
    fingerprint=$(printf '%s' "$public_key" | awk '{print $2}')
    if ! run_quiet_with_spinner 'Checking the GitHub deploy key' github_deploy_key_present "$fingerprint" \
        && ! run_quiet_with_spinner 'Configuring the GitHub deploy key' add_github_deploy_key "$public_key"; then
        print_warning 'GitHub deploy key could not be configured automatically.'
        printf 'Add this read-only deploy key to %s/%s:\n%s\n' "$GIT_OWNER" "$GIT_REPO" "$public_key" >&2
        read -r -p 'Press Enter after adding the deploy key...'
    fi
    ensure_oc_resource_owned_or_absent secret git-secret
    oc create secret generic git-secret --from-file=ssh-privatekey="$key_file" \
        --type=kubernetes.io/ssh-auth --dry-run=client -o yaml | apply_owned_oc_manifest
}
