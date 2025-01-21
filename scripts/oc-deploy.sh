#!/bin/bash

# Make the script executable
# chmod +x scripts/deploy.sh

# Color codes for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
TEAL='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored status messages
print_status() {
    echo -e "${TEAL}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}==>${NC} $1"
}

# Function to validate project name
validate_name() {
    local name=$1
    if [[ ! $name =~ ^[a-z0-9-]+$ ]]; then
        return 1
    fi
    return 0
}

# Function to validate email
validate_email() {
    local email=$1
    if [[ ! $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Function to validate git SSH URL
validate_git_url() {
    local url=$1
    # Check if URL starts with git@ or ssh:// and ends with .git
    if [[ ! $url =~ ^(git@|ssh://).+\.git$ ]]; then
        return 1
    fi
    return 0
}

# Check OpenShift client version
print_status "Checking OpenShift client version..."
OC_VERSION=$(oc version | grep "Client Version:" | awk '{print $3}' | cut -d'.' -f2)
if [ -z "$OC_VERSION" ] || [ "$OC_VERSION" -lt "14" ]; then
    print_error "OpenShift client version 4.14 or higher is required"
    print_error "Current version: $(oc version | grep "Client Version:")"
    exit 1
fi

# Check OpenShift instance and login status
print_status "Checking OpenShift instance and login status..."
if ! oc whoami --show-server &>/dev/null || ! oc whoami &>/dev/null; then
    print_error "Not logged into OpenShift. Please login first using:"
    echo "oc login --token=<token> --server=<server-url>"
    exit 1
fi

OPENSHIFT_SERVER=$(oc whoami --show-server)
echo -e "${TEAL}You are about to deploy to:${NC}"
echo -e "${TEAL}$OPENSHIFT_SERVER${NC}"
read -p "Do you want to continue? (y/n): " CONTINUE

if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
    print_error "Deployment cancelled"
    exit 1
fi

# Collect all required inputs
echo
echo -e "${TEAL}Welcome to the OpenShift Deployment Script!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${TEAL}Please provide the following information:${NC}"
echo -e "${GREEN}----------------------------------------${NC}"
echo

# Project name with validation
while true; do
    read -p "Choose an OpenShift project name (lowercase letters, numbers and hyphens only): " PROJECT_NAME
    if validate_name "$PROJECT_NAME"; then
        break
    else
        print_error "Invalid project name. Use only lowercase letters, numbers and hyphens."
    fi
done

# App name
while true; do
    read -p "Choose an application name (lowercase letters, numbers and hyphens only): " APP_NAME
    if validate_name "$APP_NAME"; then
        break
    else
        print_error "Invalid app name. Use only lowercase letters, numbers and hyphens."
    fi
done

# Git URL with validation
while true; do
    read -p "Your Git Repository URL (ssh format, e.g. git@github.com:user/repo.git): " GIT_URL
    if validate_git_url "$GIT_URL"; then
        break
    else
        print_error "Invalid Git SSH URL. Must start with git@ or ssh:// and end with .git"
    fi
done

read -p "Choose a Postgres username: " POSTGRES_USER
read -p "Choose a Postgres password: " POSTGRES_PASSWORD


# Create project
print_status "Creating new project..."
oc new-project $PROJECT_NAME || {
    print_error "Failed to create project"
    exit 1
}

# Create SSH keys
print_status "Creating SSH key pair in ~/.ssh/$PROJECT_NAME/..."
mkdir -p $HOME/.ssh/$PROJECT_NAME
ssh-keygen -N '' -f $HOME/.ssh/$PROJECT_NAME/ocp-key -C "openshift-deploy-key" -q <<< y > /dev/null

# Create OpenShift secret
print_status "Creating OpenShift secret..."
oc create secret generic git-secret \
    --from-file=ssh-privatekey=$HOME/.ssh/$PROJECT_NAME/ocp-key \
    --type=kubernetes.io/ssh-auth

print_status "${GREEN}Please add this public key to your GitLab/GitHub repository as a deploy key:${NC}"
echo -e "${TEAL}$(cat $HOME/.ssh/$PROJECT_NAME/ocp-key.pub)${NC}"
read -p "Press enter once you've added the deploy key..."

# Deploy Database
print_status "Deploying PostgreSQL database..."
oc new-app --template=postgresql-persistent \
    --param=POSTGRESQL_USER=$POSTGRES_USER \
    --param=POSTGRESQL_PASSWORD=$POSTGRES_PASSWORD

print_status "Waiting for PostgreSQL to be ready..."
# Wait for deployment to complete
sleep 2  # Give OpenShift a moment to create resources
oc rollout status dc/postgresql --timeout=300s

# Wait for the pod to be ready
sleep 2
while [[ $(oc get pods -l name=postgresql -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    print_status "Waiting for PostgreSQL pod to be ready..."
    sleep 5
done

print_status "Creating application database..."
sleep 2
# More robust pod name detection
POD_NAME=$(oc get pods -l name=postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec $POD_NAME -- psql -c 'CREATE DATABASE app;'

# Deploy Backend
print_status "Deploying backend..."
oc new-app --name=backend --strategy=docker --context-dir=backend --source-secret=git-secret $GIT_URL

# Setup backend environment
print_status "Setting up backend environment..."

oc create secret generic backend-envs \
    --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    --from-literal=FIRST_SUPERUSER_PASSWORD=$FIRST_SUPERUSER_PASSWORD \
    --from-literal=POSTGRES_DB=app \
    --from-literal=BACKEND_CORS_ORIGINS="*" \
    --from-literal=POSTGRES_PORT=5432 \
    --from-literal=POSTGRES_SERVER=postgresql \
    --from-literal=PROJECT_NAME=$PROJECT_NAME \
    --from-literal=POSTGRES_USER=$POSTGRES_USER \
    --from-literal=ENVIRONMENT=production \

print_status "Applying backend environment..."
oc patch deployment backend --patch '{"spec":{"template":{"spec":{"containers":[{"name":"backend","envFrom":[{"secretRef":{"name":"backend-envs"}}]}]}}}}'

# Group resources as one application
print_status "Grouping resources as one application..."
oc label deployment/backend dc/postgresql app.kubernetes.io/part-of=$APP_NAME

# Setup CI/CD webhooks
print_status "Getting webhook URLs..."

# Create RoleBinding for webhook access
print_status "Creating RoleBinding for webhook access..."
cat << EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  name: webhook-access-unauthenticated
  namespace: $PROJECT_NAME
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: "system:webhook"
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: "system:unauthenticated"
EOF

BACKEND_BASE_URL=$(oc describe bc/backend | grep "Webhook Generic" -A 1 | tail -n 1 | tr -d ' ')
BACKEND_SECRET=$(oc get bc backend -o jsonpath='{.spec.triggers[*].generic.secret}')
BACKEND_WEBHOOK=${BACKEND_BASE_URL/<secret>/$BACKEND_SECRET}

print_success "Deployment completed successfully!"
echo
echo "Backend Webhook URL:"
echo $BACKEND_WEBHOOK
echo
print_status "Please add this webhook URL to your GitLab/GitHub repository"
echo