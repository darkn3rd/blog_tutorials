#!/usr/bin/env bash
# validate_crds.sh — Verify Gateway API CRDs are installed in the cluster.
#
# Usage:
#   validate_crds.sh --channel <standard|experimental> --source <gateway-api|aws-gateway|all>
#
# Options:
#   -c, --channel   Channel of the Gateway API manifests used during install.
#                   One of: standard, experimental  (default: experimental)
#   -s, --source    Which CRD group(s) to validate.
#                   One of: gateway-api, aws-gateway, all  (default: all)
#   -h, --help      Show this help message.
#
# Exit codes:
#   0  All expected CRDs are present.
#   1  One or more CRDs are missing, or a usage/connectivity error occurred.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/crd_lists.sh
source "$SCRIPT_DIR/lib/crd_lists.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────

usage() {
  awk '/^#!/{next} /^#/{sub(/^# ?/,""); print; next} /^[[:space:]]*$/{next} {exit}' "$0"
  exit 0
}

die() { echo "❌ $*" >&2; exit 1; }

verify_kubectl() {
  command -v kubectl >/dev/null 2>&1 \
    || die "kubectl not found. Please install it and ensure your KUBECONFIG is set."
  kubectl cluster-info >/dev/null 2>&1 \
    || die "Cannot reach the Kubernetes cluster. Check your KUBECONFIG context and credentials."
}

# fetch_installed_crds <nameref>
# Loads all CRD names currently in the cluster into an associative array.
fetch_installed_crds() {
  local -n _installed="${1:?nameref is required}"
  _installed=()
  while IFS= read -r name; do
    [[ -n "$name" ]] && _installed[$name]=1
  done < <(kubectl get crds --no-headers \
             -o custom-columns='NAME:.metadata.name' 2>/dev/null)
}

# ── Core logic ────────────────────────────────────────────────────────────────

# validate_group <heading> <installed_nameref> <crd1> [crd2 ...]
# Prints a headed section for one CRD group. Increments the global
# TOTAL_MISSING counter so the caller can produce an aggregate summary.
TOTAL_EXPECTED=0
TOTAL_MISSING=0

validate_group() {
  local heading="$1"
  local installed_ref="$2"
  shift 2
  local -a crds=("$@")
  local -n _inst="$installed_ref"

  echo ""
  echo "  $heading"
  echo "  $(printf '─%.0s' $(seq 1 ${#heading}))"

  local group_missing=0
  for crd in "${crds[@]}"; do
    if [[ -n "${_inst[$crd]+_}" ]]; then
      echo "  ✅  $crd"
    else
      echo "  ❌  $crd"
      (( group_missing++ )) || true
    fi
  done

  TOTAL_EXPECTED=$(( TOTAL_EXPECTED + ${#crds[@]} ))
  TOTAL_MISSING=$(( TOTAL_MISSING + group_missing ))
}

validate_crds() {
  local channel="$1"
  local source="$2"

  local -A installed=()
  fetch_installed_crds installed

  echo "──────────────────────────────────────────────────────────"
  echo "  CRD Validation"
  echo "──────────────────────────────────────────────────────────"

  case "$source" in
    gateway-api)
      if [[ "$channel" == "experimental" ]]; then
        validate_group "Gateway API  (experimental channel)" installed \
          "${EXPERIMENTAL_GATEWAY_CRDS[@]}"
      else
        validate_group "Gateway API  (standard channel)" installed \
          "${STANDARD_GATEWAY_CRDS[@]}"
      fi
      ;;
    aws-gateway)
      validate_group "AWS Gateway" installed \
        "${AWS_GATEWAY_CRDS[@]}"
      ;;
    all)
      if [[ "$channel" == "experimental" ]]; then
        validate_group "Gateway API  (experimental channel)" installed \
          "${EXPERIMENTAL_GATEWAY_CRDS[@]}"
      else
        validate_group "Gateway API  (standard channel)" installed \
          "${STANDARD_GATEWAY_CRDS[@]}"
      fi
      validate_group "AWS Gateway" installed \
        "${AWS_GATEWAY_CRDS[@]}"
      ;;
  esac

  echo ""
  echo "──────────────────────────────────────────────────────────"

  local total_found=$(( TOTAL_EXPECTED - TOTAL_MISSING ))
  if [[ $TOTAL_MISSING -eq 0 ]]; then
    echo "  ✅  All $TOTAL_EXPECTED CRDs present."
    return 0
  else
    echo "  ❌  $total_found of $TOTAL_EXPECTED CRDs present  ($TOTAL_MISSING missing)." >&2
    return 1
  fi
}

# ── Argument parsing ──────────────────────────────────────────────────────────

main() {
  local channel="experimental"
  local source="all"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--channel)
        channel="${2:?--channel requires a value}"
        shift 2
        ;;
      -s|--source)
        source="${2:?--source requires a value}"
        shift 2
        ;;
      -h|--help) usage ;;
      *) die "Unknown argument '$1'. Pass --help for usage." ;;
    esac
  done

  verify_kubectl
  validate_crds "$channel" "$source"
}

main "$@"
