#!/usr/bin/env bash

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
    local kind name confirmation
    print_warning "Destructive reset targets exactly: deployment/postgresql service/postgresql pvc/postgresql-data (instance=$APP_NAME)."
    read -r -p "Type '$PROJECT_NAME' to confirm permanent database deletion: " confirmation
    [[ "$confirmation" == "$PROJECT_NAME" ]] || { print_error 'database reset cancelled'; return 1; }
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
