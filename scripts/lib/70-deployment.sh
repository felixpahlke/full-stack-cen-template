#!/usr/bin/env bash
#
# Application Deployment Library
#
# This library provides:
# - Frontend deployment
# - Backend deployment
# - Build configuration
# - Application grouping
#
#############################################
# Application Deployment Functions
#############################################

# Function to configure buildconfig webhook branch filter
configure_buildconfig_branch_filter() {
    local buildconfig_name=$1
    local branch_filter="${DEPLOYMENT_BRANCH_FILTER:-}"
    
    if [[ -n "$branch_filter" ]]; then
        print_status "Configuring $buildconfig_name to build only from branch: $branch_filter" "deployment"
        
        # Update the Git source ref to specify the branch
        if oc patch bc/$buildconfig_name --type=json -p "[
            {
                \"op\": \"add\",
                \"path\": \"/spec/source/git/ref\",
                \"value\": \"$branch_filter\"
            }
        ]" 2>&1; then
            print_success "Branch filter configured for $buildconfig_name (ref: $branch_filter)" "deployment"
        else
            print_warning "Failed to configure branch filter for $buildconfig_name" "deployment"
        fi
        
        # Add branch filter to webhook triggers using allowEnv
        # This ensures webhooks only trigger builds for the specified branch
        local trigger_count
        trigger_count=$(oc get bc/$buildconfig_name -o json | jq '.spec.triggers | length')
        
        for ((i=1; i<trigger_count; i++)); do
            local trigger_type
            trigger_type=$(oc get bc/$buildconfig_name -o json | jq -r ".spec.triggers[$i].type")
            
            if [[ "$trigger_type" == "GitHub" ]] || [[ "$trigger_type" == "Generic" ]]; then
                local trigger_key=$(echo "$trigger_type" | tr '[:upper:]' '[:lower:]')
                
                # Add allowEnv and env filter for the trigger
                oc patch bc/$buildconfig_name --type=json -p "[
                    {
                        \"op\": \"add\",
                        \"path\": \"/spec/triggers/$i/$trigger_key/allowEnv\",
                        \"value\": true
                    },
                    {
                        \"op\": \"add\",
                        \"path\": \"/spec/triggers/$i/$trigger_key/env\",
                        \"value\": [{\"name\": \"GIT_REF\", \"value\": \"refs/heads/$branch_filter\"}]
                    }
                ]" 2>/dev/null || print_warning "Could not add env filter to $trigger_type trigger at index $i" "deployment"
            fi
        done
    fi
}

# Function to deploy frontend
deploy_frontend() {
    print_status "Deploying frontend..." "deployment"
    
    # Check if frontend app already exists
    if resource_exists "buildconfig" "frontend"; then
        print_status "Frontend buildconfig already exists, triggering rollout restart..." "deployment"
        # Just restart the deployment to pick up new environment variables
        # Don't rebuild unless explicitly requested
        if resource_exists "deployment" "frontend"; then
            oc rollout restart deployment/frontend
            oc rollout status deployment/frontend --timeout=300s
        else
            print_warning "Frontend deployment not found, skipping restart" "deployment"
        fi
    else
        print_status "Creating new frontend application..." "deployment"
        oc new-app --name=frontend --strategy=docker --context-dir=frontend --source-secret=git-secret "$GIT_SSH_URL"
    fi
    
    # Configure branch filter if specified
    configure_buildconfig_branch_filter "frontend"
    
    # Check if route exists
    if ! resource_exists "route" "frontend"; then
        if ! is_oauth_enabled; then
            print_status "Exposing frontend service (OAuth disabled)..." "deployment"
            oc create route edge frontend --service=frontend --port=8080
        else
            print_status "Skipping frontend route creation (OAuth enabled)" "deployment"
        fi
    else
        if is_oauth_enabled; then
            print_warning "Frontend route exists but OAuth is enabled. Deleting public route..." "deployment"
            oc delete route frontend
        else
            print_status "Frontend route already exists, skipping creation" "deployment"
        fi
    fi
    
    return 0
}

# Function to deploy backend
deploy_backend() {
    print_status "Deploying backend..." "deployment"
    
    # Check if backend app already exists
    if resource_exists "buildconfig" "backend"; then
        print_status "Backend buildconfig already exists, triggering rollout restart..." "deployment"
        # Just restart the deployment to pick up new environment variables
        # Don't rebuild unless explicitly requested
        if resource_exists "deployment" "backend"; then
            oc rollout restart deployment/backend
            oc rollout status deployment/backend --timeout=300s
        else
            print_warning "Backend deployment not found, skipping restart" "deployment"
        fi
    else
        print_status "Creating new backend application..." "deployment"
        oc new-app --name=backend --strategy=docker --context-dir=backend --source-secret=git-secret "$GIT_SSH_URL"
    fi
    
    # Configure branch filter if specified
    configure_buildconfig_branch_filter "backend"
    
    # Check if route exists
    if ! resource_exists "route" "backend"; then
        if ! is_oauth_enabled; then
            print_status "Exposing backend service (OAuth disabled)..." "deployment"
            oc create route edge backend --service=backend --port=8000
        else
            print_status "Skipping backend route creation (OAuth enabled)" "deployment"
        fi
    else
        if is_oauth_enabled; then
            print_warning "Backend route exists but OAuth is enabled. Deleting public route..." "deployment"
            oc delete route backend
        else
            print_status "Backend route already exists, skipping creation" "deployment"
        fi
    fi
    
    return 0
}

# Function to configure frontend build with environment variables
configure_frontend() {
    # Build VITE_ build arguments JSON array
    # Note: Vite embeds these at BUILD time, so they must be build args, not runtime env vars
    local vite_buildargs_json="["
    local first=true
    local has_args=false
    
    # Add all VITE_ prefixed variables from .env.production file
    if [[ -f "$ENV_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            
            # Extract variable name and value
            if [[ "$line" =~ ^(VITE_[A-Za-z0-9_]+)=(.*)$ ]]; then
                local var_name="${BASH_REMATCH[1]}"
                local var_value="${BASH_REMATCH[2]}"
                
                # Remove quotes if present
                var_value="${var_value#\"}"
                var_value="${var_value%\"}"
                var_value="${var_value#\'}"
                var_value="${var_value%\'}"
                
                # Do not automatically set VITE_API_URL
                # nginx.conf handles the /api proxy, so relative paths work by default
                
                if [[ "$first" == "false" ]]; then
                    vite_buildargs_json+=","
                fi
                vite_buildargs_json+="{\"name\":\"$var_name\",\"value\":\"$var_value\"}"
                first=false
                has_args=true
                print_status "Found $var_name in .env.production" "deployment"
            fi
        done < "$ENV_FILE"
    fi
    
    vite_buildargs_json+="]"
    
    # Only patch and rebuild if we actually have VITE arguments
    if [[ "$has_args" == "true" ]]; then
        # Configure frontend build with all VITE_ variables as BUILD ARGS
        print_status "Configuring frontend build with VITE_ build arguments..." "deployment"
        oc patch bc/frontend --type=merge -p "{\"spec\":{\"strategy\":{\"dockerStrategy\":{\"buildArgs\":$vite_buildargs_json}}}}"
        
        print_status "Restarting frontend build to apply build args..." "deployment"
        oc cancel-build bc/frontend --state=new --state=pending --state=running 2>/dev/null || true
        oc start-build bc/frontend
    else
        print_status "No VITE_ variables found in .env.production. Skipping frontend rebuild." "deployment"
    fi
    
    return 0
}

# Function to configure backend environment
configure_backend() {
    local secret_name="$APP_NAME-env"
    
    print_status "Applying backend environment from $secret_name secret..." "deployment"
    oc patch deployment backend --patch "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"backend\",\"envFrom\":[{\"secretRef\":{\"name\":\"$secret_name\"}}]}]}}}}"
    
    return 0
}

# Function to group resources as one application
group_resources() {
    print_status "Grouping resources as one application..." "deployment"
    
    # Label core deployments
    local resources_to_label=("deployment/backend")
    
    if resource_exists "deployment" "postgresql"; then
        resources_to_label+=("deployment/postgresql")
    fi
    
    if resource_exists "deployment" "frontend"; then
        resources_to_label+=("deployment/frontend")
    fi
    
    oc label "${resources_to_label[@]}" app.kubernetes.io/part-of="$APP_NAME" --overwrite
    
    # Label OAuth proxy if it exists
    if resource_exists "deployment" "oauth-proxy"; then
        oc label deployment/oauth-proxy app.kubernetes.io/part-of="$APP_NAME" --overwrite
        print_status "OAuth2 Proxy included in application group" "deployment"
    fi
    
    return 0
}

# Made with Bob
