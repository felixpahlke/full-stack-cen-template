#!/usr/bin/env bash
#
# OpenShift Deployment Script (Refactored)
#
# This script deploys an application to OpenShift with the following features:
# - Modular library structure for maintainability
# - Idempotent operations (can be run multiple times without side effects)
# - Variables loaded dynamically from .env.production file
# - Comprehensive validation for all required variables
# - Best practices for bash scripting
# - Sensitive values are masked in output
# - Dynamic secret creation from environment variables
# - Automatic VITE_ prefix injection for frontend
# - SSH key management with GitHub deploy key verification
# - Database reset functionality
# - GitHub webhook automation
# - Clean summary output at the end
#
# Usage: ./oc-deploy.sh [OPTIONS]
#
# For detailed documentation, see scripts/README.md
#

set -eo pipefail

# Get directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source all library files in order
for lib_file in "$LIB_DIR"/*.sh; do
    if [[ -f "$lib_file" ]]; then
        # shellcheck source=/dev/null
        source "$lib_file"
    fi
done

# Default environment file location (project root)
ENV_FILE="$PROJECT_ROOT/.env.production"

# Default GitHub host (can be overridden in .env.production)
# Set to github.ibm.com for IBM GitHub Enterprise
# Set to github.com for public GitHub
DEFAULT_GITHUB_HOST="github.ibm.com"

# Flags
RESET_PROD_DB=false
REGENERATE_SSH_KEY=false
SHOW_HELP=false
SHOW_ENV_VALUES=false
DEPLOY_BACKEND_ONLY=false
FLAG_BACKEND_ONLY=false
DEPLOY_DB=true
FLAG_NO_DB=false

#############################################
# Argument Parsing
#############################################

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                SHOW_HELP=true
                shift
                ;;
            --env-file)
                ENV_FILE="$2"
                shift 2
                ;;
            --backend-only)
                FLAG_BACKEND_ONLY=true
                shift
                ;;
            --no-db)
                FLAG_NO_DB=true
                shift
                ;;
            --reset-prod-db)
                RESET_PROD_DB=true
                shift
                ;;
            --regenerate-ssh-key)
                REGENERATE_SSH_KEY=true
                shift
                ;;
            --show-env-values)
                SHOW_ENV_VALUES=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

#############################################
# Main Execution
#############################################

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show help if requested
    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help
        exit 0
    fi
    
    echo
    echo -e "${TEAL}Welcome to the OpenShift Deployment Script!${NC}"
    echo
    
    # ============================================================
    # PHASE 1: INITIALIZATION
    # ============================================================
    print_section_header "PHASE 1: INITIALIZATION"
    
    # Load environment variables from file
    load_env_file "$ENV_FILE" "$SHOW_ENV_VALUES" || exit 1
    
    # Flag overrides environment file for backend-only deployment
    if [[ "$FLAG_BACKEND_ONLY" == "true" ]]; then
        DEPLOY_BACKEND_ONLY=true
        print_status "Backend-only deployment enabled via flag (overrides environment file)"
    elif [[ "${DEPLOY_BACKEND_ONLY}" == "true" ]]; then
        print_status "Backend-only deployment enabled via environment file"
    fi
    
    # Handle No-DB flag/env
    if [[ "$FLAG_NO_DB" == "true" ]]; then
        DEPLOY_DB=false
        print_status "Database deployment disabled via flag"
    elif [[ "${DEPLOY_DB}" == "false" ]]; then
        print_status "Database deployment disabled via environment variable"
    fi
    
    # Enforce that --no-db requires backend-only mode
    if [[ "$DEPLOY_DB" == "false" && "$DEPLOY_BACKEND_ONLY" == "false" ]]; then
        print_error "The --no-db option (or DEPLOY_DB=false) is only supported in Backend-Only mode."
        print_error "Please also use --backend-only or set DEPLOY_BACKEND_ONLY=true."
        exit 1
    fi
    
    # Export for libraries to use
    export DEPLOY_BACKEND_ONLY
    export DEPLOY_DB
    
    # Validate all required variables
    validate_required_vars || exit 1
    
    # ============================================================
    # PHASE 2: PREREQUISITES CHECK
    # ============================================================
    print_section_header "PHASE 2: PREREQUISITES CHECK"
    
    # Check OpenShift client and login
    check_oc_version || exit 1
    check_oc_login || exit 1
    
    # ============================================================
    # PHASE 3: PROJECT SETUP
    # ============================================================
    print_section_header "PHASE 3: PROJECT SETUP"
    
    # Setup project
    setup_project || exit 1
    
    # Handle SSH key regeneration flag
    if [[ "$REGENERATE_SSH_KEY" == "true" ]]; then
        delete_ssh_keys || exit 1
    fi
    
    # Setup SSH keys
    setup_ssh_keys || exit 1
    
    # Handle database reset flag
    if [[ "$RESET_PROD_DB" == "true" ]]; then
        reset_production_database || exit 1
        print_deployment_summary
        exit 0
    fi
    
    # ============================================================
    # PHASE 4: DATABASE DEPLOYMENT
    # ============================================================
    print_section_header "PHASE 4: DATABASE DEPLOYMENT"
    
    # Create the initial app environment secret
    create_initial_app_env_secret || exit 1
    
    # Deploy database
    if [[ "$DEPLOY_DB" == "true" ]]; then
        deploy_database || exit 1
    else
        print_status "Skipping database deployment (DEPLOY_DB=false)"
    fi

    # Pre-configure OAuth to avoid backend restarts
    if is_oauth_enabled; then
        print_status "OAuth2 Proxy is enabled. Pre-configuring secrets to avoid backend restarts..."
        # Order matters: we need the route first to get the URL for the secret
        create_oauth_proxy_service || exit 1
        create_oauth_proxy_route || exit 1
        create_oauth_proxy_secret || exit 1
        update_backend_with_oauth_url || exit 1
    fi
    
    # ============================================================
    # PHASE 5: APPLICATION DEPLOYMENT
    # ============================================================
    print_section_header "PHASE 5: APPLICATION DEPLOYMENT"
    
    # Deploy frontend and backend
    if [[ "$DEPLOY_BACKEND_ONLY" == "false" ]]; then
        deploy_frontend || exit 1
    else
        print_status "Skipping frontend deployment (backend-only mode)"
    fi
    
    deploy_backend || exit 1
    
    # Update the app environment secret with frontend/backend URLs
    update_app_env_secret_with_urls || exit 1
    
    # Deploy OAuth2 Proxy (optional)
    # Requires all OAuth2 Proxy environment variables to be configured in .env.production
    # See scripts/.env.production.example for required variables
    if is_oauth_enabled; then
        print_status "OAuth2 Proxy is enabled, deploying..."
        deploy_oauth_proxy || exit 1
    fi
    
    # ============================================================
    # PHASE 6: CONFIGURATION
    # ============================================================
    print_section_header "PHASE 6: CONFIGURATION"
    
    # Configure frontend and backend
    if [[ "$DEPLOY_BACKEND_ONLY" == "false" ]]; then
        configure_frontend || exit 1
    fi
    
    configure_backend || exit 1
    
    # Group resources
    group_resources || exit 1
    
    # ============================================================
    # PHASE 7: POST-DEPLOYMENT
    # ============================================================
    print_section_header "PHASE 7: POST-DEPLOYMENT"
    
    # Setup webhooks
    setup_webhooks || exit 1
    
    # Print deployment summary
    print_deployment_summary
    
    return 0
}

# Execute main function with all arguments
main "$@"

# Made with Bob