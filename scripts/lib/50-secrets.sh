#!/usr/bin/env bash
#
# Secret Management Library
#
# This library provides:
# - Dynamic secret creation from environment variables
# - VITE_ variable collection
# - Initial application environment secret creation
# - Secret updates with URLs
#
#############################################
# Secret Management Functions
#############################################

# Function to build dynamic secret creation command
build_secret_literals() {
    local secret_literals=""
    
    # Read all variables from env file
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        # Extract variable name and value
        if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${!var_name:-}"
            
            # Skip GitHub credentials
            if [[ "$var_name" == "GITHUB_HOST" || "$var_name" == "GITHUB_TOKEN" ]]; then
                continue
            fi

            # Add to secret literals
            secret_literals+=" --from-literal=$var_name=\"$var_value\""
        fi
    done < "$ENV_FILE"
    
    echo "$secret_literals"
}

# Function to get all VITE_ prefixed variables
get_vite_variables() {
    local vite_vars=""
    
    # Get all exported variables
    while IFS='=' read -r name value; do
        if [[ $name == VITE_* ]]; then
            vite_vars+=" --from-literal=$name=\"$value\""
        fi
    done < <(env)
    
    echo "$vite_vars"
}

# Function to create initial application environment secret
create_initial_app_env_secret() {
    local secret_name="$APP_NAME-env"
    local secret_key_generated=false
    
    # Generate a secure random secret key if not provided or too short
    if [[ -z "${SECRET_KEY:-}" ]] || [[ ${#SECRET_KEY} -lt 8 ]]; then
        SECRET_KEY=$(openssl rand -hex 32)
        export SECRET_KEY
        secret_key_generated=true
        print_success "Generated secure secret key for backend" "secrets"
        
        # Store in output collector
        add_deployment_output "secret_key_generated" "$SECRET_KEY"
    fi
    
    # Create or update application environment secret
    if resource_exists "secret" "$secret_name"; then
        print_status "Updating $secret_name secret..." "secrets"
        oc delete secret "$secret_name"
    fi
    
    print_status "Creating initial application environment secret $secret_name..." "secrets"
    
    # Build dynamic secret creation command
    local secret_cmd="oc create secret generic $secret_name"
    secret_cmd+=$(build_secret_literals)
    
    # Execute the command
    eval "$secret_cmd"
    
    return 0
}

# Function to update application environment secret with frontend/backend URLs
update_app_env_secret_with_urls() {
    local secret_name="$APP_NAME-env"
    local frontend_url
    local backend_url
    
    # Get the frontend and backend URLs from the routes
    frontend_url=$(oc get route frontend -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    backend_url=$(oc get route backend -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    
    # If OAuth is enabled, these routes might not exist (which is expected).
    # We will defer the URL updates to the OAuth phase in that case.
    if is_oauth_enabled; then
        print_status "OAuth is enabled - skipping standard URL updates (will be handled by OAuth deployment)" "secrets"
        return 0
    fi
    
    if [[ -z "$frontend_url" || -z "$backend_url" ]]; then
        print_error "Could not get frontend or backend URLs. Make sure the routes are created." "secrets"
        return 1
    fi
    
    print_status "Updating $secret_name secret with frontend and backend URLs..." "secrets"
    
    # Set BACKEND_CORS_ORIGINS if not already set, or append backend URL if it exists
    if [[ -z "${BACKEND_CORS_ORIGINS:-}" ]]; then
        export BACKEND_CORS_ORIGINS="https://$frontend_url"
    else
        # Add backend URL to existing BACKEND_CORS_ORIGINS if not already present
        if [[ ! "$BACKEND_CORS_ORIGINS" =~ "https://$frontend_url" ]]; then
            export BACKEND_CORS_ORIGINS="$BACKEND_CORS_ORIGINS,https://$frontend_url"
            print_status "Added frontend URL to existing BACKEND_CORS_ORIGINS" "secrets"
        fi
    fi
    
    # Set DOMAIN for backend
    export DOMAIN="$backend_url"
    
    # Store URLs in output collector
    add_deployment_output "frontend_url" "$frontend_url"
    add_deployment_output "backend_url" "$backend_url"
    add_deployment_output "backend_cors_origins" "$BACKEND_CORS_ORIGINS"
    add_deployment_output "domain" "$DOMAIN"
    
    # Delete the existing secret
    oc delete secret "$secret_name"
    
    # Recreate the secret with all values including URLs
    print_status "Recreating application environment secret with URLs..." "secrets"
    local secret_cmd="oc create secret generic $secret_name"
    secret_cmd+=$(build_secret_literals)
    
    # Execute the command
    eval "$secret_cmd"
    
    print_success "Updated environment secret with frontend URL: https://$frontend_url and backend URL: https://$backend_url" "secrets"
    return 0
}

# Made with Bob
