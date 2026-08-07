#!/usr/bin/env bash

# The integrated registry is cluster-wide and cannot be safely claimed by one application.
# Deployment therefore verifies readiness but never patches the operator configuration.
setup_image_registry() {
    local state storage endpoints
    state=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.managementState}' 2>/dev/null || true)
    storage=$(oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.storage}' 2>/dev/null || true)
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
