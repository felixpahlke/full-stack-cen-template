#!/usr/bin/env bash
#
# Environment Management Library
#
# This library provides:
# - Environment variable loading from .env files
# - Required variable validation
# - Password validation
#
# Required main environment variables
declare -a REQUIRED_VARS=(
    "APP_NAME"
    "PROJECT_NAME"
    "GIT_SSH_URL"
    "FIRST_SUPERUSER"
    "FIRST_SUPERUSER_PASSWORD"
    "SIGNUP_ACCESS_PASSWORD"
    "ENVIRONMENT"
    "SECRET_KEY"
    "POSTGRES_SERVER"
    "POSTGRES_PORT"
    "POSTGRES_DB"
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
)

# OAuth2 Proxy variables (conditionally required - all or nothing)
declare -a OAUTH_VARS=(
    "OAUTH2_PROXY_COOKIE_SECRET"
    "OAUTH2_PROXY_CLIENT_ID"
    "OAUTH2_PROXY_CLIENT_SECRET"
    "OAUTH2_PROXY_OIDC_ISSUER_URL"
)

# Variables that need password length validation (min 8 chars)
declare -a PASSWORD_VARS=(
    "FIRST_SUPERUSER_PASSWORD"
    "POSTGRES_PASSWORD"
    "SECRET_KEY"
)

#############################################
# Environment Loading Functions
#############################################

# Function to load environment variables from file
load_env_file() {
    local env_file=$1
    local show_values=${2:-false}
    
    if [[ ! -f "$env_file" ]]; then
        print_error "Environment file $env_file not found!" "environment"
        print_error "Please create $env_file with all required variables." "environment"
        print_error "See scripts/.env.production.example for reference." "environment"
        return 1
    fi
    
    print_status "Loading environment variables from $env_file" "environment"
    
    # Load variables from env file without executing any code
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        # Extract variable name and value
        if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
            var_name="${BASH_REMATCH[1]}"
            var_value="${BASH_REMATCH[2]}"
            
            # Remove quotes if present
            var_value="${var_value#\"}"
            var_value="${var_value%\"}"
            var_value="${var_value#\'}"
            var_value="${var_value%\'}"
            
            # Export the variable
            export "$var_name"="$var_value"
            
            # Display variable only if show_values flag is true
            if [[ "$show_values" == "true" ]]; then
                print_status "Loaded $var_name=$var_value" "environment"
            fi
        fi
    done < "$env_file"
    
    return 0
}

# Function to validate OAuth variables (all-or-nothing)
validate_oauth_vars() {
    local oauth_vars_set=()
    local oauth_vars_missing=()
    
    # Check which OAuth vars are set
    for var_name in "${OAUTH_VARS[@]}"; do
        if [[ -n "${!var_name:-}" ]]; then
            oauth_vars_set+=("$var_name")
        else
            oauth_vars_missing+=("$var_name")
        fi
    done
    
    # If no OAuth vars set, OAuth is disabled - OK
    if [[ ${#oauth_vars_set[@]} -eq 0 ]]; then
        print_status "OAuth2 Proxy is disabled (no OAuth variables configured)" "environment"
        return 0
    fi
    
    # If some but not all OAuth vars set - ERROR
    if [[ ${#oauth_vars_missing[@]} -gt 0 ]]; then
        print_error "OAuth2 Proxy is partially configured. All OAuth variables must be set or all must be empty." "environment"
        print_error "Missing OAuth variables:" "environment"
        for var_name in "${oauth_vars_missing[@]}"; do
            echo "  - $var_name"
        done
        return 1
    fi
    
    # All OAuth vars are set - validate COOKIE_SECRET length (min 16 chars)
    if [[ ${#OAUTH2_PROXY_COOKIE_SECRET} -lt 16 ]]; then
        print_error "OAUTH2_PROXY_COOKIE_SECRET must be at least 16 characters (current: ${#OAUTH2_PROXY_COOKIE_SECRET})" "environment"
        return 1
    fi
    
    print_success "OAuth2 Proxy configuration is valid!" "environment"
    return 0
}

# Function to validate all required variables
validate_required_vars() {
    local missing_vars=()
    local invalid_vars=()
    
    print_status "Validating required environment variables..." "environment"
    
    # Check if all required variables are set
    for var_name in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var_name:-}" ]]; then
            missing_vars+=("$var_name")
        fi
    done
    
    # Report missing variables
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "The following required environment variables are missing:" "environment"
        for var_name in "${missing_vars[@]}"; do
            echo "  - $var_name"
        done
        print_error "Please add these variables to your environment file: $ENV_FILE" "environment"
        return 1
    fi
    
    # Validate specific variables
    local vars_to_validate=("APP_NAME" "PROJECT_NAME" "GIT_SSH_URL" "FIRST_SUPERUSER" "API_KEY")
    for var_name in "${vars_to_validate[@]}"; do
        local validation_func=$(get_validation_function "$var_name")
        local var_value="${!var_name:-}"
        
        if [[ -n "$validation_func" && -n "$var_value" ]]; then
            if ! $validation_func "$var_value"; then
                invalid_vars+=("$var_name")
            fi
        fi
    done
    
    # Validate password lengths
    for var_name in "${PASSWORD_VARS[@]}"; do
        local var_value="${!var_name:-}"
        
        # Skip empty optional passwords
        if [[ "$var_name" == "SIGNUP_ACCESS_PASSWORD" && -z "$var_value" ]]; then
            continue
        fi
        
        if [[ -n "$var_value" ]] && ! validate_password_length "$var_value" "$var_name"; then
            invalid_vars+=("$var_name")
        fi
    done
    
    # Report invalid variables
    if [[ ${#invalid_vars[@]} -gt 0 ]]; then
        print_error "The following environment variables have invalid values:" "environment"
        for var_name in "${invalid_vars[@]}"; do
            echo "  - $var_name"
        done
        return 1
    fi
    
    # Validate OAuth variables (conditional)
    if ! validate_oauth_vars; then
        return 1
    fi
    
    print_success "All required environment variables are valid!" "environment"
    return 0
}

# Made with Bob
