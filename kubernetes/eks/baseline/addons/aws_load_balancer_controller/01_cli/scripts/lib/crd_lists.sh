#!/usr/bin/env bash
# lib/crd_lists.sh — Shared CRD definitions for Gateway API validation and cleanup.
# Source this file; do not execute it directly.

STANDARD_GATEWAY_CRDS=(
  backendtlspolicies.gateway.networking.k8s.io
  gatewayclasses.gateway.networking.k8s.io
  gateways.gateway.networking.k8s.io
  grpcroutes.gateway.networking.k8s.io
  httproutes.gateway.networking.k8s.io
  listenersets.gateway.networking.k8s.io
  referencegrants.gateway.networking.k8s.io
  tlsroutes.gateway.networking.k8s.io
)

EXPERIMENTAL_GATEWAY_CRDS=(
  gatewayclasses.gateway.networking.k8s.io
  gateways.gateway.networking.k8s.io
  grpcroutes.gateway.networking.k8s.io
  httproutes.gateway.networking.k8s.io
  listenersets.gateway.networking.k8s.io
  referencegrants.gateway.networking.k8s.io
  tcproutes.gateway.networking.k8s.io
  tlsroutes.gateway.networking.k8s.io
  udproutes.gateway.networking.k8s.io
)

AWS_GATEWAY_CRDS=(
  listenerruleconfigurations.gateway.k8s.aws
  loadbalancerconfigurations.gateway.k8s.aws
  targetgroupconfigurations.gateway.k8s.aws
)

# resolve_crds <channel> <source> <nameref>
#
# Populates <nameref> with the deduplicated CRD list for the given combination.
#
# channel : standard | experimental
# source  : gateway-api | aws-gateway | all
# nameref : name of the caller's array variable to populate (bash 4.3+)
resolve_crds() {
  local channel="${1:?channel is required (standard|experimental)}"
  local source="${2:?source is required (gateway-api|aws-gateway|all)}"
  local -n _resolved="${3:?output nameref is required}"

  local -a channel_crds=()
  case "$channel" in
    standard)     channel_crds=("${STANDARD_GATEWAY_CRDS[@]}") ;;
    experimental) channel_crds=("${EXPERIMENTAL_GATEWAY_CRDS[@]}") ;;
    *)
      echo "❌ Unknown channel '$channel'. Use 'standard' or 'experimental'." >&2
      return 1
      ;;
  esac

  local -a pool=()
  case "$source" in
    gateway-api)  pool=("${channel_crds[@]}") ;;
    aws-gateway)  pool=("${AWS_GATEWAY_CRDS[@]}") ;;
    all)          pool=("${channel_crds[@]}" "${AWS_GATEWAY_CRDS[@]}") ;;
    *)
      echo "❌ Unknown source '$source'. Use 'gateway-api', 'aws-gateway', or 'all'." >&2
      return 1
      ;;
  esac

  # Deduplicate while preserving order
  local -A seen=()
  _resolved=()
  for crd in "${pool[@]}"; do
    if [[ -z "${seen[$crd]+_}" ]]; then
      seen[$crd]=1
      _resolved+=("$crd")
    fi
  done
}
