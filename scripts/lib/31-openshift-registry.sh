#############################################
# Image Registry Setup Functions
#############################################

verify_registry_state() {
    local tmp_status

    # Check Operator
    tmp_status=$(oc get clusteroperator image-registry 2>/dev/null)
    print_status "Cluster Operator Status:\n$tmp_status" "openshift"

    # Check Config
    tmp_status=$(oc get configs.imageregistry.operator.openshift.io cluster -o yaml 2>/dev/null)
    print_status "Registry Config:\n$tmp_status" "openshift"

    tmp_status=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.managementState}' 2>/dev/null)
    print_status "Registry Management State:\n$tmp_status" "openshift"

    # Check Pods
    tmp_status=$(oc get pods -n openshift-image-registry 2>/dev/null)
    print_status "Registry Pods:\n$tmp_status" "openshift"

    tmp_status=$(oc get deployment image-registry -n openshift-image-registry 2>/dev/null)
    print_status "Deployment Status:\n$tmp_status" "openshift"

    tmp_status=$(oc get deployment image-registry -n openshift-image-registry -o jsonpath='{.status.replicas}/{.spec.replicas}' 2>/dev/null)
    print_status "Verify desired replicas match actual:\n$tmp_status" "openshift"

    # Check Service
    tmp_status=$(oc get svc image-registry -n openshift-image-registry 2>/dev/null)
    print_status "Service exists and has endpoint:\n$tmp_status" "openshift"

    tmp_status=$(oc get endpoints image-registry -n openshift-image-registry 2>/dev/null)
    print_status "Check service endpoints:\n$tmp_status" "openshift"

    # Check Storage
    tmp_status=$(oc get pvc -n openshift-image-registry 2>/dev/null)
    print_status "Verify PVC is bound:\n$tmp_status" "openshift"

    tmp_status=$(oc get pv | grep image-registry 2>/dev/null)
    print_status "Check PVC status:\n$tmp_status" "openshift"

    # Check Route/Access
    tmp_status=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)
    print_status "Get internal registry hostname:\n$tmp_status" "openshift"

    tmp_status=$(oc get route -n openshift-image-registry 2>/dev/null)
    print_status "Check if route exists:\n$tmp_status" "openshift"

    # Test registry Functionality
    tmp_status=$(oc registry login 2>/dev/null)
    print_status "Login to registry:\n$tmp_status" "openshift"

    tmp_status=$(oc registry info 2>/dev/null)
    print_status "Registry URL:\n$tmp_status" "openshift"

    tmp_status=$(oc new-build --binary --name=test-build -n default 2>/dev/null)
    print_status "Verify PVC is bound:\n$tmp_status" "openshift"

    # Check Logs
    tmp_status=$(oc logs -n openshift-image-registry deployment/image-registry --tail=50 2>/dev/null)
    print_status "Registry pod logs:\n$tmp_status" "openshift"

    tmp_status=$(oc logs -n openshift-image-registry deployment/cluster-image-registry-operator --tail=50 2>/dev/null)
    print_status "Operator logs:\n$tmp_status" "openshift"

    tmp_status=$(oc get events -n openshift-image-registry --sort-by='.lastTimestamp' | grep -i error 2>/dev/null)
    print_status "Check error in events:\n$tmp_status" "openshift"
}

#############################################
# Storage Detection Functions
#############################################

# Get current storage type from registry config
# Returns: "pvc", "emptyDir", or "none"
_get_storage_type() {
    local storage_spec
    storage_spec=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.storage}' 2>/dev/null)

    [[ -z "$storage_spec" || "$storage_spec" == "{}" ]] && echo "none" && return
    echo "$storage_spec" | grep -q "pvc" && echo "pvc" && return
    echo "$storage_spec" | grep -q "emptyDir" && echo "emptyDir" && return
    echo "none"
}

# Get current defaultRoute setting
# Returns: "true", "false", or "unknown"
_get_default_route() {
    local route_setting
    route_setting=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.defaultRoute}' 2>/dev/null)

    [[ -z "$route_setting" ]] && echo "unknown" && return
    echo "$route_setting"
}

# Check if PVC exists and get its status
# Returns: "bound", "pending", or "notfound"
_get_pvc_status() {
    local pvc_name=$1

    oc get pvc "$pvc_name" -n openshift-image-registry &>/dev/null || { echo "notfound"; return; }
    oc get pvc "$pvc_name" -n openshift-image-registry -o jsonpath='{.status.phase}' 2>/dev/null
}

# Check if registry needs configuration
# Returns: 0 if needs config, 1 if already configured
# Also sets global CONFIG_TYPE to "full" or "route-only"
_needs_configuration() {
    local state=$1
    local storage=$2
    local default_route=$3

    # Removed or Unmanaged = needs full configuration
    if [[ "$state" == "Removed" || "$state" == "Unmanaged" ]]; then
        CONFIG_TYPE="full"
        return 0
    fi

    # Managed without storage = needs full configuration
    if [[ "$state" == "Managed" && "$storage" == "none" ]]; then
        CONFIG_TYPE="full"
        return 0
    fi

    # Managed with storage but defaultRoute not true = needs route fix
    if [[ "$state" == "Managed" && "$storage" != "none" && "$default_route" != "true" ]]; then
        CONFIG_TYPE="route-only"
        return 0
    fi

    # Already fully configured = no action needed
    return 1
}

#############################################
# Storage Setup Functions
#############################################

# Create PVC for registry storage
_create_pvc() {
    local pvc_name=$1

    print_status "Creating PVC: $pvc_name" "openshift"

    apply_resource "$(cat << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc_name
  namespace: openshift-image-registry
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF
)"
}

# Determine which storage type to use
# Returns: "pvc" or "emptyDir"
_determine_storage_type() {
    local create_pvc="${OPENSHIFT_REGISTRY_PVC_CREATE:-false}"
    local pvc_name="registry-storage-pvc"

    # If PVC creation not requested, use emptyDir
    [[ "$create_pvc" != "true" ]] && echo "emptyDir" && return

    print_status "PVC creation requested, checking PVC status" "openshift"

    local pvc_status
    pvc_status=$(_get_pvc_status "$pvc_name")

    case "$pvc_status" in
        Bound)
            print_success "PVC $pvc_name is bound" "openshift"
            echo "pvc"
            return
            ;;
        Pending)
            print_warning "PVC $pvc_name is pending, falling back to emptyDir" "openshift"
            echo "emptyDir"
            return
            ;;
        notfound)
            print_status "PVC $pvc_name not found, creating it" "openshift"
            if _create_pvc "$pvc_name"; then
                sleep 2
                pvc_status=$(_get_pvc_status "$pvc_name")
                if [[ "$pvc_status" == "Bound" ]]; then
                    print_success "PVC created and bound" "openshift"
                    echo "pvc"
                    return
                fi
                print_warning "PVC created but not bound, falling back to emptyDir" "openshift"
            else
                print_warning "PVC creation failed, falling back to emptyDir" "openshift"
            fi
            echo "emptyDir"
            return
            ;;
        *)
            print_warning "PVC in unknown state, falling back to emptyDir" "openshift"
            echo "emptyDir"
            return
            ;;
    esac
}

#############################################
# Registry Configuration Functions
#############################################

# Apply registry configuration
# Parameters:
#   $1: storage_type ("pvc" or "emptyDir") - ignored for route-only
#   $2: config_type ("full" or "route-only")
_apply_registry_config() {
    local storage_type=$1
    local config_type=$2
    local pvc_name="registry-storage-pvc"
    local patch_json

    if [[ "$config_type" == "route-only" ]]; then
        print_status "Enabling defaultRoute for registry" "openshift"
        patch_json='{"spec":{"defaultRoute":true}}'
    elif [[ "$storage_type" == "pvc" ]]; then
        print_status "Configuring registry with PVC storage" "openshift"
        patch_json="{\"spec\":{\"defaultRoute\":true,\"rolloutStrategy\":\"Recreate\",\"managementState\":\"Managed\",\"replicas\":1,\"storage\":{\"managementState\":\"Unmanaged\",\"pvc\":{\"claim\":\"$pvc_name\"}}}}"
    else
        print_warning "Configuring registry with emptyDir (ephemeral storage)" "openshift"
        patch_json='{"spec":{"defaultRoute":true,"rolloutStrategy":"Recreate","managementState":"Managed","replicas":1,"storage":{"emptyDir":{}}}}'
    fi

    if oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch "$patch_json" &>/dev/null; then
        if [[ "$config_type" == "route-only" ]]; then
            print_success "defaultRoute enabled" "openshift"
        else
            print_success "Registry configured with $storage_type storage" "openshift"
        fi
        return 0
    else
        print_error "Failed to configure registry" "openshift"
        return 1
    fi
}

# Wait for registry pods to be ready
_wait_for_registry() {
    print_status "Waiting for registry to be ready..." "openshift"

    local max_wait=60
    local waited=0

    while [ $waited -lt $max_wait ]; do
        local running_pods
        running_pods=$(oc get pods -n openshift-image-registry -l docker-registry=default --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

        if [ "$running_pods" -eq 1 ]; then
            print_success "Registry is ready" "openshift"
            return 0
        fi

        sleep 5
        waited=$((waited + 5))
        echo -n "."
    done

    print_warning "Registry may still be starting" "openshift"
    return 0
}

#############################################
# Main Setup Function
#############################################

# Main function to setup OpenShift image registry
setup_image_registry() {

    # Check permissions
    if ! oc auth can-i patch configs.imageregistry.operator.openshift.io/cluster &>/dev/null; then
        print_warning "No permissions to manage image registry" "openshift"
        print_warning "If builds fail, ask your cluster admin to enable the registry" "openshift"
        return 0
    fi

    # Get current state
    local registry_state
    registry_state=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.managementState}' 2>/dev/null)

    if [[ -z "$registry_state" ]]; then
        print_warning "Could not determine registry state" "openshift"
        return 0
    fi

    print_status "Registry state: $registry_state" "openshift"

    # Get current storage
    local current_storage
    current_storage=$(_get_storage_type)
    print_status "Current storage: $current_storage" "openshift"

    # Get current defaultRoute setting
    local default_route
    default_route=$(_get_default_route)
    print_status "Default route: $default_route" "openshift"

    # Check if configuration needed (sets global CONFIG_TYPE)
    CONFIG_TYPE=""
    if ! _needs_configuration "$registry_state" "$current_storage" "$default_route"; then
        print_success "Registry already configured - skipping" "openshift"
        return 0
    fi

    # Handle route-only configuration
    if [[ "$CONFIG_TYPE" == "route-only" ]]; then
        _apply_registry_config "" "route-only" || return 1
        return 0
    fi

    # Handle full configuration
    local storage_type
    storage_type=$(_determine_storage_type)

    _apply_registry_config "$storage_type" "full" || return 1

    _wait_for_registry

    return 0
}
