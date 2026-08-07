#!/usr/bin/env bash

# The integrated registry is cluster-wide and cannot be safely claimed by one application.
# Deployment therefore verifies readiness but never patches the operator configuration.
can_read_registry_state() {
    local answer
    for permission in \
        'get configs.imageregistry.operator.openshift.io/cluster' \
        'get deployments.apps/image-registry -n openshift-image-registry' \
        'watch deployments.apps/image-registry -n openshift-image-registry' \
        'get endpoints/image-registry -n openshift-image-registry'; do
        answer=$(oc auth can-i $permission 2>/dev/null || true)
        [[ "$answer" == yes ]] || return 1
    done
}

setup_image_registry() {
    local state storage endpoints
    if ! can_read_registry_state; then
        print_warning 'Cannot inspect openshift-image-registry with the current account; continuing without the readiness gate.'
        print_warning 'Required read access: registry config, image-registry Deployment (get/watch), and image-registry Endpoints.'
        print_warning 'If builds fail, ask a cluster administrator to verify that the integrated registry is managed and ready.'
        return 0
    fi
    state=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.managementState}')
    storage=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.storage}')
    if [[ "$state" != Managed || -z "$storage" || "$storage" == '{}' ]]; then
        print_error 'integrated registry is not managed with configured storage; ask a cluster administrator to configure it'
        return 1
    fi
    run oc rollout status -n openshift-image-registry deployment/image-registry --timeout=10m
    endpoints=$(oc get endpoints image-registry -n openshift-image-registry -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    [[ -n "$endpoints" ]] || { print_error 'integrated registry has no ready endpoints'; return 1; }
    oc registry info >/dev/null 2>&1 || { print_error 'oc could not resolve the integrated registry'; return 1; }
    print_success 'Integrated OpenShift registry is ready.'
}
