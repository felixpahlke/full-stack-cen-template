#!/bin/bash

export LANG=en_US.UTF-8

### ------------------------ PRELIMINARIES ------------------------ ###
set -e

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
TEAL='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${TEAL}==>     $1${NC}"; }
print_success() { echo -e "${GREEN}==>     $1${NC}"; }
print_error() { echo -e "${RED}==>     $1${NC}"; }
print_warning() { echo -e "${YELLOW}==>     $1${NC}"; }
print_section() {
    echo ""
    echo -e "${TEAL}========================================${NC}"
    echo -e "${TEAL}  $1${NC}"
    echo -e "${TEAL}========================================${NC}"
}

print_section "PRE-CHECKS"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE=$SCRIPT_DIR/../.env.production

if [ ! -f "$ENV_FILE" ]; then
    print_error ".env.production file not found at $ENV_FILE"
    print_error "Please create it from .env.production.tpl first"
    exit 1
fi

source $ENV_FILE

# Validate _CE_PROJECT_NAME length
if [ ${#_CE_PROJECT_NAME} -gt 20 ]; then
    print_error "_CE_PROJECT_NAME must be 20 characters or less (current: ${#_CE_PROJECT_NAME})"
    print_error "This is because derived names (like namespace) must be <= 30 chars."
    exit 1
fi

# Set defaults for optional variables (can be overridden in .env.production)
_CE_FRONTEND_IMAGE_NAME="${_CE_FRONTEND_IMAGE_NAME:-frontend}"
_CE_FRONTEND_APPLICATION_NAME="${_CE_FRONTEND_APPLICATION_NAME:-${_CE_PROJECT_NAME}-frontend}"
_CE_BACKEND_IMAGE_NAME="${_CE_BACKEND_IMAGE_NAME:-backend}"
_CE_BACKEND_ENV_SECRET_NAME="${_CE_BACKEND_ENV_SECRET_NAME:-${_CE_PROJECT_NAME}-backend-config}"
_CE_BACKEND_APPLICATION_NAME="${_CE_BACKEND_APPLICATION_NAME:-${_CE_PROJECT_NAME}-backend}"
_CR_REGISTRY_SECRET_NAME="${_CR_REGISTRY_SECRET_NAME:-${_CE_PROJECT_NAME}-registry-secret}"
_CR_NAMESPACE="${_CR_NAMESPACE:-${_CE_PROJECT_NAME}-namespace}"

# Validate _CEN_FLAVOR
if [ -z "${_CEN_FLAVOR}" ]; then
    print_error "_CEN_FLAVOR is missing in .env.production"
    print_error "Please set it to one of: local-auth, backend-only, oauth-proxy, backend-only-no-db, local-auth-custom-ui, oauth-proxy-custom-ui"
    exit 1
fi

print_status "Deployment Identity: ${_CEN_FLAVOR}"

# Initialize required variables with common ones
REQUIRED_VARS=(
    "_IBM_CLOUD_RESOURCE_GROUP" "_IBM_CLOUD_REGION" "_IBM_CLOUD_ACCOUNT_NAME"
    "_CE_PROJECT_NAME" "_CR_REGISTRY"
)

# Add database variables if NOT backend-only-no-db
if [[ "${_CEN_FLAVOR}" != "backend-only-no-db" ]]; then
    REQUIRED_VARS+=("POSTGRES_SERVER" "POSTGRES_PORT" "POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD")
fi

# OAuth Configuration
if [[ "${_CEN_FLAVOR}" == "oauth-proxy" || "${_CEN_FLAVOR}" == "oauth-proxy-custom-ui" ]]; then
    REQUIRED_VARS+=("OAUTH2_PROXY_COOKIE_SECRET" "OAUTH2_PROXY_CLIENT_ID" "OAUTH2_PROXY_CLIENT_SECRET" "OAUTH2_PROXY_OIDC_ISSUER_URL")
    OAUTH_ENABLED=true
else
    OAUTH_ENABLED=false
fi

print_status "Validating required environment variables..."
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        print_error "  - $var"
    done
    exit 1
fi
print_success "All required environment variables are set"

check_nginx_config() {
    print_status "Checking nginx configuration..."
    NGINX_CONF="$SCRIPT_DIR/../frontend/nginx.conf"
    
    if [ -f "$NGINX_CONF" ]; then
        # Check if "location /api" is active (not commented out)
        if grep -E "^\s*location /api" "$NGINX_CONF" | grep -vE "^\s*#" > /dev/null; then
            print_error "Found active 'location /api' block in frontend/nginx.conf"
            print_error "Please comment out or remove the 'location /api' block for CE deployments."
            exit 1
        fi
        print_success "nginx.conf check passed"
    else
        print_warning "nginx.conf not found at $NGINX_CONF - skipping check"
    fi
}

check_nginx_config

### ------------------------ IBM CLOUD SETUP ------------------------ ###
print_section "IBM CLOUD SETUP"

# Check and install required plugins
print_status "Checking for required IBM Cloud plugins..."
# Check for container-registry plugin
if ! ibmcloud plugin show container-registry &>/dev/null; then
    print_status "Installing container-registry plugin..."
    ibmcloud plugin install -f container-registry || { print_error "Failed to install container-registry plugin"; exit 1; }
else
    print_success "container-registry plugin is installed"
fi

# Check for code-engine plugin
if ! ibmcloud plugin show code-engine &>/dev/null; then
    print_status "Installing code-engine plugin..."
    ibmcloud plugin install -f code-engine || { print_error "Failed to install code-engine plugin"; exit 1; }
else
    print_success "code-engine plugin is installed"
fi

# Check IBM Cloud login
print_status "Checking IBM Cloud login status..."
if ibmcloud account show &>/dev/null; then
    print_success "Already logged in to IBM Cloud"
    
    # Check if logged in to the correct account
    current_account=$(ibmcloud account show | grep "Account Name:" | awk -F': ' '{print $2}' | xargs)
    expected_account=$(echo "${_IBM_CLOUD_ACCOUNT_NAME}" | xargs)
    
    if [[ "$current_account" == "$expected_account" ]]; then
        print_success "Logged in to the correct account: ${_IBM_CLOUD_ACCOUNT_NAME}"
    else
        print_error "Logged in to wrong account: $current_account"
        print_status "Logging in to the correct account: ${_IBM_CLOUD_ACCOUNT_NAME}..."
        ibmcloud logout
        ibmcloud login -sso || { print_error "Failed to login to IBM Cloud"; exit 1; }
    fi
else
    print_error "Not logged in. Logging in to IBM Cloud..."
    ibmcloud login -sso || { print_error "Failed to login to IBM Cloud"; exit 1; }
fi

# Set resource group and region
print_status "Setting resource group and region from .env.production..."
ibmcloud target -g ${_IBM_CLOUD_RESOURCE_GROUP} || { print_error "Failed to select resource group"; exit 1; } 
ibmcloud target -r ${_IBM_CLOUD_REGION} || { print_error "Failed to select region"; exit 1; }

### ------------------------ CONTAINER REGISTRY SETUP ------------------------ ###
print_section "CONTAINER REGISTRY SETUP"

# Login to Container Registry
print_status "Logging in to Container Registry..."
ibmcloud cr login || { print_error "Failed to login to Container Registry"; exit 1; }

# Check if namespace exists, create if not
print_status "Checking if Container Registry namespace '${_CR_NAMESPACE}' exists..."
if ibmcloud cr namespace-list | grep -q "^${_CR_NAMESPACE}$"; then
    print_success "Container Registry namespace '${_CR_NAMESPACE}' already exists"
else
    print_status "Creating Container Registry namespace '${_CR_NAMESPACE}'..."
    ibmcloud cr namespace-add ${_CR_NAMESPACE} || { print_error "Failed to create namespace"; exit 1; }
    print_success "Container Registry namespace '${_CR_NAMESPACE}' created successfully!"
fi

### ------------------------ CODE ENGINE PROJECT SETUP ------------------------ ###
print_section "CODE ENGINE PROJECT SETUP"

# Check if Code Engine project exists, create if not
print_status "Checking if Code Engine project '${_CE_PROJECT_NAME}' exists..."
if ibmcloud ce project get -n ${_CE_PROJECT_NAME} &>/dev/null; then
    print_success "Code Engine project '${_CE_PROJECT_NAME}' already exists"
    print_status "Selecting Code Engine project..."
    ibmcloud ce project select -n ${_CE_PROJECT_NAME} --kubecfg || { print_error "Failed to select CE project"; exit 1; }
else
    print_status "Creating Code Engine project '${_CE_PROJECT_NAME}'..."
    ibmcloud ce project create -n ${_CE_PROJECT_NAME} || { print_error "Failed to create CE project"; exit 1; }
    print_success "Code Engine project '${_CE_PROJECT_NAME}' created successfully!"

    # Wait for project to be ready
    print_status "Waiting for project to be ready..."
    sleep 10
    print_status "Selecting Code Engine project..."
    ibmcloud ce project select -n ${_CE_PROJECT_NAME} --kubecfg || { print_error "Failed to select CE project"; exit 1; }
fi

# Get the project subdomain and extract cluster ID
print_status "Fetching Code Engine project subdomain..."
CE_SUBDOMAIN=$(ibmcloud ce project current | grep "Subdomain:" | awk '{print $2}')
if [ -z "$CE_SUBDOMAIN" ]; then
    print_error "Failed to get Code Engine project subdomain"
    exit 1
fi
print_success "Code Engine subdomain: $CE_SUBDOMAIN"

# Extract cluster ID from subdomain
# Subdomain format: <project-name>.<cluster-id>
# We need to get the cluster ID to construct proper URLs
print_status "Extracting cluster identifier from subdomain..."
CLUSTER_ID=$(echo "$CE_SUBDOMAIN" | cut -d'.' -f2)
if [ -z "$CLUSTER_ID" ]; then
    print_error "Failed to extract cluster ID from subdomain"
    exit 1
fi
print_success "Extracted Cluster ID: $CLUSTER_ID"

### ------------------------ REGISTRY SECRET SETUP ------------------------ ###
print_section "REGISTRY SECRET SETUP"

# Check if registry secret exists, create if not
print_status "Checking if registry secret '${_CR_REGISTRY_SECRET_NAME}' exists..."
if ibmcloud ce registry get --name ${_CR_REGISTRY_SECRET_NAME} &>/dev/null; then
    print_success "Registry secret '${_CR_REGISTRY_SECRET_NAME}' already exists"
else
    print_status "Creating registry secret '${_CR_REGISTRY_SECRET_NAME}'..."
    
    # Check if IAM API key is provided
    if [ -z "${_IAM_API_KEY}" ]; then
        print_error "IAM API key (_IAM_API_KEY) is required to create registry secret"
        print_error "Please add it to your .env.production file"
        exit 1
    fi
    ibmcloud ce registry create \
        --name ${_CR_REGISTRY_SECRET_NAME} \
        --server ${_CR_REGISTRY} \
        --username iamapikey \
        --password ${_IAM_API_KEY} || { print_error "Failed to create registry secret"; exit 1; }
    print_success "Registry secret '${_CR_REGISTRY_SECRET_NAME}' created successfully!"
fi

# Check if OAuth2 Proxy should be deployed
if [ "$OAUTH_ENABLED" = true ]; then
    print_success "OAuth2 Proxy flavor detected - will deploy with OAuth protection"
else
    print_status "OAuth2 Proxy not enabled for flavor '${_CEN_FLAVOR}'"
fi

### ------------------------ OAUTH2 PROXY DEPLOYMENT (IF ENABLED) ------------------------ ###
deploy_oauth_proxy() {
    if [ "$OAUTH_ENABLED" = true ]; then
        print_section "DEPLOYING OAUTH2 PROXY"
        
        # Construct OAuth proxy URL
        OAUTH_PROXY_URL="https://oauth-proxy.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
        
        # Create or update OAuth proxy secrets
        if ! ibmcloud ce secret get --name oauth-proxy-secret &>/dev/null; then
            print_status "Creating OAuth proxy secrets..."
            ibmcloud ce secret create --name oauth-proxy-secret \
                --from-literal=OAUTH2_PROXY_COOKIE_DOMAIN=oauth-proxy.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud \
                --from-literal=OAUTH2_PROXY_COOKIE_SECRET=${OAUTH2_PROXY_COOKIE_SECRET} \
                --from-literal=OAUTH2_PROXY_CLIENT_ID=${OAUTH2_PROXY_CLIENT_ID} \
                --from-literal=OAUTH2_PROXY_CLIENT_SECRET=${OAUTH2_PROXY_CLIENT_SECRET} \
                --from-literal=OAUTH2_PROXY_OIDC_ISSUER_URL=${OAUTH2_PROXY_OIDC_ISSUER_URL} \
                --from-literal=OAUTH2_PROXY_REDIRECT_URL=${OAUTH_PROXY_URL}/oauth2/callback || { print_error "Failed to create OAuth secrets"; exit 1; }
        else
            print_status "Updating OAuth proxy secrets..."
            ibmcloud ce secret update --name oauth-proxy-secret \
                --from-literal=OAUTH2_PROXY_COOKIE_DOMAIN=oauth-proxy.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud \
                --from-literal=OAUTH2_PROXY_COOKIE_SECRET=${OAUTH2_PROXY_COOKIE_SECRET} \
                --from-literal=OAUTH2_PROXY_CLIENT_ID=${OAUTH2_PROXY_CLIENT_ID} \
                --from-literal=OAUTH2_PROXY_CLIENT_SECRET=${OAUTH2_PROXY_CLIENT_SECRET} \
                --from-literal=OAUTH2_PROXY_OIDC_ISSUER_URL=${OAUTH2_PROXY_OIDC_ISSUER_URL} \
                --from-literal=OAUTH2_PROXY_REDIRECT_URL=${OAUTH_PROXY_URL}/oauth2/callback || { print_error "Failed to update OAuth secrets"; exit 1; }
        fi
        
        # Deploy or update OAuth proxy application
        if ibmcloud ce application get --name oauth-proxy &>/dev/null; then
            print_status "Updating OAuth proxy application..."
            ibmcloud ce application update \
                --name oauth-proxy \
                --env-from-secret oauth-proxy-secret \
                --min-scale 1 --max-scale 2 --scale-down-delay 600 || { print_error "Failed to update OAuth proxy"; exit 1; }
        else
            print_status "Creating OAuth proxy application..."
            ibmcloud ce application create \
                --name oauth-proxy \
                --image quay.io/oauth2-proxy/oauth2-proxy:latest \
                --port http1:4180 --cpu 0.25 --memory 0.5G \
                --min-scale 1 --max-scale 2 --scale-down-delay 600 \
                --env-from-secret oauth-proxy-secret \
                --probe-live initial-delay=10 --probe-live type=http --probe-live path=/ping --probe-live port=4180 \
                --probe-ready initial-delay=10 --probe-ready type=http --probe-ready path=/ping --probe-ready port=4180 \
                --argument="--provider=oidc" \
                --argument="--email-domain=*" \
                --argument="--http-address=:4180" \
                --argument="--pass-authorization-header=true" \
                --argument="--insecure-oidc-allow-unverified-email=true" \
                --argument="--pass-host-header=false" \
                --argument="--skip-provider-button=true" \
                --argument="--upstream-timeout=300s" \
                --argument="--upstream=http://${_CE_FRONTEND_APPLICATION_NAME}.${CE_SUBDOMAIN}.svc.cluster.local/" \
                --argument="--upstream=http://${_CE_BACKEND_APPLICATION_NAME}.${CE_SUBDOMAIN}.svc.cluster.local/api/" \
                --argument="--upstream=http://${_CE_BACKEND_APPLICATION_NAME}.${CE_SUBDOMAIN}.svc.cluster.local/static/" || { print_error "Failed to create OAuth proxy"; exit 1; }
        fi
        print_success "OAuth proxy deployed successfully!"
        
        # Set URLs to use OAuth proxy
        BACKEND_URL="${OAUTH_PROXY_URL}"
        FRONTEND_URL="${OAUTH_PROXY_URL}"
        OAUTH_REDIRECT_URL="${OAUTH_PROXY_URL}/oauth2/callback"
    else
        # Construct direct application URLs (no OAuth)
        BACKEND_URL="https://${_CE_BACKEND_APPLICATION_NAME}.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
        FRONTEND_URL="https://${_CE_FRONTEND_APPLICATION_NAME}.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
    fi
    
    print_success "Constructed URLs:"
    print_status "  Backend URL:  $BACKEND_URL"
    print_status "  Frontend URL: $FRONTEND_URL"
    if [ "$OAUTH_ENABLED" = true ]; then
        print_status "  OAuth Redirect URL: $OAUTH_REDIRECT_URL"
    fi
}

### ------------------------ UPDATE ENV FILE ------------------------ ###
update_env_file() {
    print_section "UPDATING ENVIRONMENT FILE"
    
    print_status "Updating environment variables in .env.production..."
    
    # Create a temporary file
    TEMP_FILE="${ENV_FILE}.tmp"
    
    # Update or add the required variables
    VITE_API_URL_UPDATED=false
    BACKEND_CORS_UPDATED=false
    OAUTH_REDIRECT_UPDATED=false
    
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | tr -d '\r')
        if [[ $line == VITE_API_URL=* ]]; then
            echo "VITE_API_URL=\"${BACKEND_URL}\""
            VITE_API_URL_UPDATED=true
        elif [[ $line == BACKEND_CORS_ORIGINS=* ]]; then
            echo "BACKEND_CORS_ORIGINS=\"${FRONTEND_URL}\""
            BACKEND_CORS_UPDATED=true
        elif [[ $line == OAUTH2_PROXY_REDIRECT_URL=* ]] && [ "$OAUTH_ENABLED" = true ]; then
            echo "OAUTH2_PROXY_REDIRECT_URL=\"${OAUTH_REDIRECT_URL}\""
            OAUTH_REDIRECT_UPDATED=true
        else
            echo "$line"
        fi
    done < "$ENV_FILE" > "$TEMP_FILE"
    
    # Add variables if they weren't found in the file
    if [ "$VITE_API_URL_UPDATED" = false ]; then
        echo "VITE_API_URL=\"${BACKEND_URL}\"" >> "$TEMP_FILE"
    fi
    if [ "$BACKEND_CORS_UPDATED" = false ]; then
        echo "BACKEND_CORS_ORIGINS=\"${FRONTEND_URL}\"" >> "$TEMP_FILE"
    fi
    if [ "$OAUTH_ENABLED" = true ]; then
        if [ "$OAUTH_REDIRECT_UPDATED" = false ]; then
            echo "OAUTH2_PROXY_REDIRECT_URL=\"${OAUTH_REDIRECT_URL}\"" >> "$TEMP_FILE"
        fi
        
        # Infer OAUTH2_PROXY_WELL_KNOWN_URL if not present
        if ! grep -q "OAUTH2_PROXY_WELL_KNOWN_URL=" "$ENV_FILE"; then
             # Remove trailing slash from issuer url if present
            clean_issuer_url="${OAUTH2_PROXY_OIDC_ISSUER_URL%/}"
            well_known_url="${clean_issuer_url}/.well-known/openid-configuration"
            echo "OAUTH2_PROXY_WELL_KNOWN_URL=\"${well_known_url}\"" >> "$TEMP_FILE"
            print_status "  OAUTH2_PROXY_WELL_KNOWN_URL=\"${well_known_url}\" (inferred)"
        fi
    fi
    
    # Replace original file with updated one
    mv "$TEMP_FILE" "$ENV_FILE"
    
    print_success "Updated .env.production with deployment URLs"
    print_status "  VITE_API_URL=\"${BACKEND_URL}\""
    print_status "  BACKEND_CORS_ORIGINS=\"${FRONTEND_URL}\""
    if [ "$OAUTH_ENABLED" = true ]; then
        print_status "  OAUTH2_PROXY_REDIRECT_URL=\"${OAUTH_REDIRECT_URL}\""
    fi
}

### ------------------------ DEPLOYMENT FUNCTION ------------------------ ###
deploy_applications() {
    print_section "DEPLOYING APPLICATIONS"
    
    ### FRONTEND ###
    print_status "Building frontend image..."
    VITE_BUILD_ARGS=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines early to avoid xargs quote parsing issues
        if [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]]; then continue; fi
        line=$(echo "$line" | tr -d '\r' | xargs)
        if [[ $line == VITE_API_URL=* ]]; then
            VITE_BUILD_ARGS+=("--build-arg=VITE_API_URL=${BACKEND_URL}")
        elif [[ $line == VITE_* ]]; then
            VITE_BUILD_ARGS+=("--build-arg=$line")
        fi
    done < "$ENV_FILE"
    
    print_status "Found ${#VITE_BUILD_ARGS[@]} VITE build arguments"
    print_status "Building image: ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_FRONTEND_IMAGE_NAME}:latest"
    
    docker image build --platform linux/amd64 \
        -t ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_FRONTEND_IMAGE_NAME}:latest \
        "${VITE_BUILD_ARGS[@]}" \
        --build-arg NODE_ENV=${NODE_ENV:-production} \
        --load \
        ./frontend || { print_error "Failed to build frontend image"; exit 1; }
    
    print_status "Pushing frontend image..."
    docker image push ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_FRONTEND_IMAGE_NAME}:latest || { print_error "Failed to push frontend image"; exit 1; }
    
    if ibmcloud ce application get --name ${_CE_FRONTEND_APPLICATION_NAME} &>/dev/null; then
        print_status "Updating frontend application..."
        ibmcloud ce application update \
            --name ${_CE_FRONTEND_APPLICATION_NAME} \
            --image ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_FRONTEND_IMAGE_NAME}:latest \
            --min-scale 1 --max-scale 2 --scale-down-delay 600 || { print_error "Failed to update frontend"; exit 1; }
    else
        print_status "Creating frontend application..."
        # Frontend is cluster-local when OAuth is enabled, public otherwise
        if [ "$OAUTH_ENABLED" = true ]; then
            CLUSTER_LOCAL_FLAG="--cluster-local"
        else
            CLUSTER_LOCAL_FLAG=""
        fi
        
        ibmcloud ce application create \
            --name ${_CE_FRONTEND_APPLICATION_NAME} \
            --image ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_FRONTEND_IMAGE_NAME}:latest \
            --registry-secret ${_CR_REGISTRY_SECRET_NAME} \
            --port http1:8080 \
            $CLUSTER_LOCAL_FLAG \
            --probe-live initial-delay=10 --probe-live type=http --probe-live path=/healthz --probe-live port=8080 \
            --probe-ready initial-delay=10 --probe-ready type=http --probe-ready path=/healthz --probe-ready port=8080 \
            --cpu 0.5 --memory 1G \
            --min-scale 1 --max-scale 2 --scale-down-delay 600 || { print_error "Failed to create frontend"; exit 1; }
    fi
    print_success "Frontend deployed successfully!"
    
    ### BACKEND ###
    print_status "Building backend image..."
    docker image build --platform linux/amd64 \
        -t ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_BACKEND_IMAGE_NAME}:latest \
        --load \
        ./backend || { print_error "Failed to build backend image"; exit 1; }
    
    print_status "Pushing backend image..."
    docker image push ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_BACKEND_IMAGE_NAME}:latest || { print_error "Failed to push backend image"; exit 1; }
    
    # Update backend secrets with new CORS origins
    SECRET_NAME="${_CE_BACKEND_ENV_SECRET_NAME}"
    FROM_LITERALS=()
    while IFS= read -r line; do
        # Skip comments and empty lines early to avoid xargs quote parsing issues
        if [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]]; then continue; fi
        line=$(echo "$line" | xargs)
        [[ $line == _* ]] && continue
        FROM_LITERALS+=(--from-literal "$line")
    done < "$ENV_FILE"
    
    if ibmcloud ce secret get --name "$SECRET_NAME" &>/dev/null; then
        print_status "Removing existing backend secrets to ensure strict sync..."
        ibmcloud ce secret delete --name "$SECRET_NAME" --force || { print_error "Failed to delete existing secrets"; exit 1; }
    fi

    print_status "Creating backend secrets..."
    ibmcloud ce secret create --name "$SECRET_NAME" "${FROM_LITERALS[@]}" || { print_error "Failed to create secrets"; exit 1; }
    
    if ibmcloud ce application get --name "${_CE_BACKEND_APPLICATION_NAME}" &>/dev/null; then
        print_status "Updating backend application..."
        ibmcloud ce application update \
            --name "${_CE_BACKEND_APPLICATION_NAME}" \
            --image ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_BACKEND_IMAGE_NAME}:latest \
            --min-scale 1 --max-scale 2 --scale-down-delay 600 \
            --probe-live initial-delay=10 --probe-live type=http --probe-live path=/api/v1/utils/health-check/ --probe-live port=8000 \
            --probe-ready initial-delay=10 --probe-ready type=http --probe-ready path=/api/v1/utils/health-check/ --probe-ready port=8000 \
            --ephemeral-storage 1.5G || { print_error "Failed to update backend"; exit 1; }
        
        print_success "Backend application updated successfully!"
    else
        print_status "Creating backend application..."
        # Backend is cluster-local when OAuth is enabled, public otherwise
        if [ "$OAUTH_ENABLED" = true ]; then
            CLUSTER_LOCAL_FLAG="--cluster-local"
        else
            CLUSTER_LOCAL_FLAG=""
        fi
        
        ibmcloud ce application create \
            --name ${_CE_BACKEND_APPLICATION_NAME} \
            --image ${_CR_REGISTRY}/${_CR_NAMESPACE}/${_CE_BACKEND_IMAGE_NAME}:latest \
            --registry-secret ${_CR_REGISTRY_SECRET_NAME} \
            --port http1:8000 \
            $CLUSTER_LOCAL_FLAG \
            --probe-live initial-delay=10 --probe-live type=http --probe-live path=/api/v1/utils/health-check/ --probe-live port=8000 \
            --probe-ready initial-delay=10 --probe-ready type=http --probe-ready path=/api/v1/utils/health-check/ --probe-ready port=8000 \
            --cpu 1 --memory 4G --ephemeral-storage 1.5G \
            --min-scale 1 --max-scale 4 --scale-down-delay 600 \
            --env-from-secret ${_CE_BACKEND_ENV_SECRET_NAME} || { print_error "Failed to create backend"; exit 1; }
        
        print_success "Backend application created successfully!"
    fi
}

### ------------------------ MAIN DEPLOYMENT LOGIC ------------------------ ###
# Step 1: Deploy OAuth proxy (if enabled) and construct URLs
deploy_oauth_proxy

# Step 2: Update .env.production file with correct URLs
update_env_file

# Step 3: Reload environment variables with updated URLs
source $ENV_FILE

# Step 4: Deploy backend and frontend with correct API URL
deploy_applications

### ------------------------ FINAL OUTPUT ------------------------ ###
print_section "DEPLOYMENT COMPLETE"

echo ""
print_success "🎉 Deployment completed successfully!"
echo ""

print_section "APPLICATION URLS"
echo ""

if [ "$OAUTH_ENABLED" = true ]; then
    print_success "Main Application (OAuth Protected):"
    print_status "  ${OAUTH_PROXY_URL}"
    echo ""
    
    # Get direct application URLs for debugging
    BACKEND_DIRECT_URL="https://${_CE_BACKEND_APPLICATION_NAME}.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
    FRONTEND_DIRECT_URL="https://${_CE_FRONTEND_APPLICATION_NAME}.${CLUSTER_ID}.${_IBM_CLOUD_REGION}.codeengine.appdomain.cloud"
    
    print_status "Direct Access URLs (for debugging):"
    print_status "  Backend API:  ${BACKEND_DIRECT_URL}"
    print_status "  Frontend:     ${FRONTEND_DIRECT_URL}"
    echo ""
    print_warning "Note: Direct URLs bypass OAuth authentication. Use the main application URL for normal access."
else
    print_success "Frontend URL:"
    print_status "  ${FRONTEND_URL}"
    echo ""
    print_success "Backend API URL:"
    print_status "  ${BACKEND_URL}"
    echo ""
    print_warning "Note: OAuth2 Proxy is not configured. Application is publicly accessible."
fi

echo ""
print_success "✅ .env.production file has been automatically updated with deployment URLs"

print_section "INFRASTRUCTURE DETAILS"
print_status "  Resource Group:       ${_IBM_CLOUD_RESOURCE_GROUP}"
print_status "  Region:               ${_IBM_CLOUD_REGION}"
print_status "  Code Engine Project:  ${_CE_PROJECT_NAME}"
print_status "  Project Subdomain:    ${CE_SUBDOMAIN}"
print_status "  Cluster ID:           ${CLUSTER_ID}"
print_status "  Container Registry:   ${_CR_REGISTRY}/${_CR_NAMESPACE}"
if [ "$OAUTH_ENABLED" = true ]; then
    print_status "  OAuth2 Proxy:         Enabled"
else
    print_status "  OAuth2 Proxy:         Disabled"
fi
echo ""

if [ "$OAUTH_ENABLED" = true ]; then
    print_success "✅ You can now access your application at: ${OAUTH_PROXY_URL}"
else
    print_success "✅ You can now access your application at: ${FRONTEND_URL}"
fi
echo ""