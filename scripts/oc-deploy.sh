#!/usr/bin/env bash
set -euo pipefail
set +x

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$SCRIPT_DIR/lib"
for library in 00-common 30-openshift 31-openshift-registry 40-ssh 50-secrets 60-database 70-deployment 75-oauth 80-webhooks; do
    # shellcheck source=/dev/null
    source "$LIB_DIR/${library}.sh"
done
trap cleanup_deploy_tmp_files EXIT

ENV_FILE="$PROJECT_ROOT/.env.production"
RESET_PROD_DB=false
REGENERATE_SSH_KEY=false
SHOW_ENV_VALUES=false
FLAVOR_OVERRIDE=''
ADOPT_LEGACY_RESOURCES=false

parse_arguments() {
    while (($#)); do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            --env-file) ENV_FILE=${2:?}; shift 2 ;;
            --flavor) FLAVOR_OVERRIDE=${2:?}; shift 2 ;;
            --backend-only) FLAVOR_OVERRIDE=backend-only; shift ;;
            --no-db) FLAVOR_OVERRIDE=backend-only-no-db; shift ;;
            --reset-prod-db) RESET_PROD_DB=true; shift ;;
            --regenerate-ssh-key) REGENERATE_SSH_KEY=true; shift ;;
            --adopt-legacy-resources) ADOPT_LEGACY_RESOURCES=true; shift ;;
            --show-env-values) SHOW_ENV_VALUES=true; shift ;;
            --dry-run) DEPLOY_DRY_RUN=true; shift ;;
            *) print_error "unknown option: $1"; exit 2 ;;
        esac
    done
}

dry_run_plan() {
    print_status "Branch deployment identity: $CEN_DEPLOY_FLAVOR"
    if [[ "$HAS_FRONTEND" == true ]]; then print_status 'Images: backend + nginx frontend'; else print_status 'Images: backend only'; fi
    print_status "Ownership: $(cen_ownership_labels)"
    [[ "$OAUTH_ENABLED" != true ]] || print_status 'OAuth order: workload Ready -> proxy ingress apply -> owned direct-route deletion'
}

main() {
    parse_arguments "$@"
    load_branch_flavor
    enable_mock_mode
    load_env_file "$ENV_FILE" "$SHOW_ENV_VALUES"
    validate_mock_commands
    if [[ -n "$FLAVOR_OVERRIDE" && "$FLAVOR_OVERRIDE" != "$CEN_DEPLOY_FLAVOR" ]]; then
        print_error "checked-out tree is $CEN_DEPLOY_FLAVOR; refusing topology override to $FLAVOR_OVERRIDE"
        return 1
    fi
    resolve_app_name "${_APP_NAME:-${PROJECT_NAME:-cen-app}}"
    validate_runtime_env
    GIT_SSH_URL=${_GIT_SSH_URL:-${GIT_SSH_URL:-}}
    [[ -n "$GIT_SSH_URL" ]] || { print_error '_GIT_SSH_URL is required'; return 1; }
    git_repo_parts "$GIT_SSH_URL"
    resolve_deployment_branch_ref
    ensure_oauth_upstream_password

    print_section_header 'OpenShift deployment'
    if [[ "$DEPLOY_DRY_RUN" == true ]]; then dry_run_plan; return 0; fi
    check_oc_version
    check_oc_login
    confirm_target 'OpenShift deployment' "$PROJECT_NAME"
    setup_project
    adopt_legacy_resources

    # These read-only checks precede SSH, registry, secret, database, and build mutations.
    preflight_deploy_collisions
    preflight_oauth_ingress
    protect_postgres_credential_change

    if [[ "$REGENERATE_SSH_KEY" == true ]]; then delete_ssh_keys; fi
    setup_ssh_keys
    validate_remote_branch_ref
    setup_image_registry
    if [[ "$OAUTH_ENABLED" == true ]]; then update_app_env_secret_with_urls; else create_initial_app_env_secret; fi

    if [[ "$RESET_PROD_DB" == true ]]; then reset_production_database; print_deployment_summary; return 0
    elif [[ "${DB_CREDENTIAL_RESET:-false}" == true ]]; then reset_production_database true
    else deploy_database
    fi
    ensure_webhook_secret

    deploy_frontend
    deploy_backend
    if [[ "$OAUTH_ENABLED" == true ]]; then
        create_oauth_proxy_secret
        deploy_oauth_proxy
    else
        reconcile_direct_ingress
        update_app_env_secret_with_urls
        oc_resource_is_owned deployment backend || { warn_unowned_collision deployment backend; return 1; }
        run oc rollout restart deployment/backend
        run oc rollout status deployment/backend --timeout=15m
    fi
    setup_webhooks
    reconcile_obsolete_resources

    if [[ "$OAUTH_ENABLED" != true ]]; then add_deployment_output backend_url "$(capture_route_host backend)"; fi
    if [[ "$HAS_FRONTEND" == true && "$OAUTH_ENABLED" != true ]]; then add_deployment_output frontend_url "$(capture_route_host frontend)"; fi
    print_deployment_summary
}

main "$@"
