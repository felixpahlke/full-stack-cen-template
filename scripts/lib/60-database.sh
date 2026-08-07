#!/usr/bin/env bash

protect_postgres_credential_change() {
    DB_CREDENTIAL_RESET=false
    [[ "$HAS_DATABASE" == true && "${POSTGRES_SERVER:-}" == postgresql ]] || return 0
    [[ "${RESET_PROD_DB:-false}" != true ]] || return 0
    resource_exists deployment postgresql || return 0
    oc_resource_is_owned deployment postgresql || { warn_unowned_collision deployment postgresql; return 1; }

    local key current confirmation
    local changed=()
    for key in POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD; do
        if ! current=$(oc exec deployment/postgresql -- printenv "$key" 2>/dev/null); then
            print_error "cannot verify the running PostgreSQL $key before replacing application credentials"
            print_error 'Restore the database workload or use --reset-prod-db for an explicit destructive reset.'
            return 1
        fi
        [[ "$current" == "${!key}" ]] || changed+=("$key")
    done
    ((${#changed[@]})) || { print_status 'Running PostgreSQL credentials are unchanged.'; return 0; }

    print_warning "Running PostgreSQL credentials differ for: ${changed[*]}"
    print_warning 'Changing these values does not update an initialized PostgreSQL data directory.'
    print_warning 'Continuing requires deleting and reinitializing the owned PostgreSQL PVC; all database data will be lost.'
    read -r -p "Type '$PROJECT_NAME' to confirm permanent database deletion: " confirmation
    [[ "$confirmation" == "$PROJECT_NAME" ]] || {
        print_error 'credential change cancelled before application or database secrets were modified'
        return 1
    }
    DB_CREDENTIAL_RESET=true
}

deploy_database() {
    [[ "$HAS_DATABASE" == true ]] || { print_status 'Skipping database (branch has no database).'; return 0; }
    if [[ "$POSTGRES_SERVER" != postgresql ]]; then
        print_status "Using external PostgreSQL host '$POSTGRES_SERVER'."
        return 0
    fi
    ensure_oc_resource_owned_or_absent pvc postgresql-data
    ensure_oc_resource_owned_or_absent deployment postgresql
    ensure_oc_resource_owned_or_absent service postgresql
    cat <<EOF | apply_resource 'PostgreSQL'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
  labels: {$CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 1Gi}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  labels: {app: postgresql, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector: {matchLabels: {app: postgresql}}
  template:
    metadata:
      labels: {app: postgresql, app.kubernetes.io/part-of: $APP_NAME, $CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
    spec:
      containers:
        - name: postgresql
          image: postgres:12
          ports: [{name: postgresql, containerPort: 5432}]
          envFrom: [{secretRef: {name: $APP_NAME-env}}]
          env: [{name: PGDATA, value: /var/lib/postgresql/data/pgdata}]
          readinessProbe: {exec: {command: [pg_isready, -U, "\$(POSTGRES_USER)", -d, "\$(POSTGRES_DB)"]}, initialDelaySeconds: 5, periodSeconds: 10}
          volumeMounts: [{name: data, mountPath: /var/lib/postgresql/data}]
      volumes: [{name: data, persistentVolumeClaim: {claimName: postgresql-data}}]
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  labels: {$CEN_MANAGED_BY_KEY: $CEN_MANAGED_BY_VALUE, $CEN_INSTANCE_KEY: $APP_NAME}
spec:
  selector: {app: postgresql}
  ports: [{name: postgresql, port: 5432, targetPort: postgresql}]
EOF
    run oc rollout status deployment/postgresql --timeout=10m
}

reset_production_database() {
    [[ "$HAS_DATABASE" == true && "$POSTGRES_SERVER" == postgresql ]] || {
        print_error 'reset only manages this branch’s in-cluster PostgreSQL database'
        return 1
    }
    local already_confirmed=${1:-false} kind name confirmation
    print_warning "Destructive reset targets exactly: deployment/postgresql service/postgresql pvc/postgresql-data (instance=$APP_NAME)."
    if [[ "$already_confirmed" != true ]]; then
        read -r -p "Type '$PROJECT_NAME' to confirm permanent database deletion: " confirmation
        [[ "$confirmation" == "$PROJECT_NAME" ]] || { print_error 'database reset cancelled'; return 1; }
    fi
    for kind in deployment service pvc; do
        name=postgresql; [[ "$kind" == pvc ]] && name=postgresql-data
        if resource_exists "$kind" "$name" && ! oc_resource_is_owned "$kind" "$name"; then
            warn_unowned_collision "$kind" "$name"
            return 1
        fi
    done
    delete_owned_oc_resource deployment postgresql
    delete_owned_oc_resource service postgresql
    delete_owned_oc_resource pvc postgresql-data
    deploy_database
    if resource_exists deployment backend; then
        oc_resource_is_owned deployment backend || { warn_unowned_collision deployment backend; return 1; }
        run oc rollout restart deployment/backend
        run oc rollout status deployment/backend --timeout=15m
    fi
}
