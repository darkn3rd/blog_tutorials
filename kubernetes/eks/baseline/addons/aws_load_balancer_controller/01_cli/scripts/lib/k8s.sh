#!/usr/bin/env bash
# lib/k8s.sh — Shared kubectl helpers.
# Source this file; do not execute it directly.
#
# Requires: kubectl
# Assumes:  die() is defined by the sourcing script.

# verify_kubectl
# Exits via die() if kubectl is missing or the cluster is unreachable.
verify_kubectl() {
  command -v kubectl >/dev/null 2>&1 \
    || die "kubectl not found. Please install it and ensure your KUBECONFIG is set."
  kubectl cluster-info >/dev/null 2>&1 \
    || die "Cannot reach the Kubernetes cluster. Check your KUBECONFIG context and credentials."
}

# fetch_installed_crds <nameref-assoc-array>
# Loads all CRD names currently in the cluster into an associative array
# keyed by CRD name (value is always 1).
fetch_installed_crds() {
  local -n _installed="${1:?nameref is required}"
  _installed=()
  while IFS= read -r name; do
    [[ -n "$name" ]] && _installed[$name]=1
  done < <(kubectl get crds --no-headers \
             -o custom-columns='NAME:.metadata.name' 2>/dev/null)
}

# service_account_exists <name> <namespace> → 0 if exists, 1 if not
service_account_exists() {
  local sa_name="${1:?sa_name is required}"
  local namespace="${2:?namespace is required}"
  kubectl get serviceaccount "$sa_name" \
    --namespace "$namespace" \
    >/dev/null 2>&1
}

# get_service_account_annotation <name> <namespace> <annotation-key> → stdout
# Prints the value of a single annotation on a ServiceAccount, or empty string
# if the annotation is absent.
get_service_account_annotation() {
  local sa_name="${1:?sa_name is required}"
  local namespace="${2:?namespace is required}"
  local annotation_key="${3:?annotation_key is required}"

  kubectl get serviceaccount "$sa_name" \
    --namespace "$namespace" \
    -o jsonpath="{.metadata.annotations.${annotation_key}}" 2>/dev/null \
    || true
}
