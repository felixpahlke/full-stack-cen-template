#!/usr/bin/env bash
#
# Database Management Library
#
# This library provides:
# - Production database reset functionality
# - PostgreSQL deployment
# - Database configuration
#
#############################################
# Database Management Functions
#############################################

# Function to reset production database
reset_production_database() {
    print_warning "Resetting production database..." "database"
    print_warning "This will DELETE all data in the PostgreSQL database!" "database"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    
    if [[ "$CONFIRM" != "yes" ]]; then
        print_error "Database reset cancelled" "database"
        return 1
    fi
    
    # Delete PostgreSQL deployment
    if resource_exists "deployment" "postgresql"; then
        print_status "Deleting PostgreSQL deployment..." "database"
        oc delete deployment postgresql
    fi
    
    # Delete PostgreSQL service
    if resource_exists "service" "postgresql"; then
        print_status "Deleting PostgreSQL service..." "database"
        oc delete service postgresql
    fi
    
    # Delete PVC
    if resource_exists "pvc" "postgresql-data"; then
        print_status "Deleting PostgreSQL PVC..." "database"
        oc delete pvc postgresql-data
    fi
    
    print_success "Database storage deleted successfully" "database"
    
    # Recreate database
    print_status "Recreating database..." "database"
    deploy_database || return 1
    
    # Restart backend to apply migrations
    if resource_exists "deployment" "backend"; then
        print_status "Restarting backend to apply migrations..." "database"
        oc rollout restart deployment/backend
        oc rollout status deployment/backend --timeout=300s
    fi
    
    print_success "Database reset completed successfully!" "database"
    return 0
}

# Function to deploy PostgreSQL database
deploy_database() {
    local secret_name="$APP_NAME-env"
    print_status "Deploying PostgreSQL database..." "database"
    
    # Create persistent volume claim for PostgreSQL if it doesn't exist
    if ! resource_exists "pvc" "postgresql-data"; then
        print_status "Creating persistent volume claim for PostgreSQL..." "database"
        apply_resource "$(cat << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
)"
    else
        print_status "PVC postgresql-data already exists, skipping creation" "database"
    fi
    
    # Check if PostgreSQL deployment exists
    local postgres_exists=false
    if resource_exists "deployment" "postgresql"; then
        postgres_exists=true
        print_status "PostgreSQL deployment already exists" "database"
    fi
    
    # Deploy PostgreSQL using container image with values from secret
    print_status "Deploying PostgreSQL container using values from $secret_name secret..." "database"
    apply_resource "$(cat << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  labels:
    app: postgresql
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
        name: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:12
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: POSTGRES_DB
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: postgresql-data
          mountPath: "/var/lib/postgresql/data"
      volumes:
      - name: postgresql-data
        persistentVolumeClaim:
          claimName: postgresql-data
EOF
)"
    
    # Create PostgreSQL service if it doesn't exist
    if ! resource_exists "service" "postgresql"; then
        print_status "Creating PostgreSQL service..." "database"
        apply_resource "$(cat << EOF
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  labels:
    app: postgresql
spec:
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgresql
EOF
)"
    else
        print_status "Service postgresql already exists, skipping creation" "database"
    fi
    
    # If PostgreSQL deployment already existed, check if credentials changed
    if [[ "$postgres_exists" == "true" ]]; then
        print_status "Checking if PostgreSQL credentials changed..." "database"
        
        # Get current credentials from running pod
        local current_db=""
        local current_user=""
        local current_password=""
        local needs_restart=false
        
        # Check if any pod is running
        if oc get pods -l name=postgresql -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
            # Get values from the running pod
            current_db=$(oc exec deployment/postgresql -- printenv POSTGRES_DB 2>/dev/null || echo "")
            current_user=$(oc exec deployment/postgresql -- printenv POSTGRES_USER 2>/dev/null || echo "")
            current_password=$(oc exec deployment/postgresql -- printenv POSTGRES_PASSWORD 2>/dev/null || echo "")
            
            # Compare with environment variables
            if [[ "$current_db" != "$POSTGRES_DB" || "$current_user" != "$POSTGRES_USER" || "$current_password" != "$POSTGRES_PASSWORD" ]]; then
                 print_warning "PostgreSQL credentials changed in configuration!" "database"
                 echo -e "${YELLOW}Warning: Changing these variables does NOT update the running database credentials.${NC}"
                 echo -e "${YELLOW}The database was initialized with different credentials.${NC}"
                 echo -e "${YELLOW}To apply these changes, the database must be COMPLETELY RESET and REINITIALIZED.${NC}"
                 echo -e "${RED}⚠️  THIS WILL DELETE ALL EXISTING DATA! ⚠️${NC}"
                 
                 read -p "Do you want to reset the database to apply new credentials? (yes/no): " RESET_DB
                 
                 if [[ "$RESET_DB" == "yes" ]]; then
                     reset_production_database
                     return $?
                 else
                     print_warning "Proceeding without database reset. Credentials may be mismatched." "database"
                     needs_restart=true
                 fi
            else
                 print_status "PostgreSQL credentials unchanged. Skipping restart." "database"
            fi
        else
            print_warning "PostgreSQL pod not running. Triggering restart to ensure consistency..." "database"
            needs_restart=true
        fi
        
        if [[ "$needs_restart" == "true" ]]; then
            print_status "Restarting PostgreSQL deployment..." "database"
            oc rollout restart deployment/postgresql
        fi
    fi
    
    print_status "Waiting for PostgreSQL to be ready..." "database"
    # Wait for deployment to complete
    sleep 2  # Give OpenShift a moment to create resources
    oc rollout status deployment/postgresql --timeout=300s
    
    # Wait for the pod to be ready
    sleep 2
    local retries=0
    local max_retries=30
    while [[ $(oc get pods -l name=postgresql -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
        print_status "Waiting for PostgreSQL pod to be ready..." "database"
        sleep 5
        ((retries++))
        if [[ $retries -ge $max_retries ]]; then
            print_error "PostgreSQL pod did not become ready in time" "database"
            return 1
        fi
    done
    
    print_success "PostgreSQL deployment completed successfully!" "database"
    return 0
}

# Made with Bob
