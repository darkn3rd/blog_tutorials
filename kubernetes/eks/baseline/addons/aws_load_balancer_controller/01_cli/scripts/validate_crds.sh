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

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  # Print contiguous leading comment block (lines 2–N until first blank/code line)
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

validate_crds() {
  local channel="$1"
  local source="$2"

  local -a expected=()
  resolve_crds "$channel" "$source" expected || exit 1

  echo "Validating CRDs  [channel: $channel]  [source: $source]"
  echo "──────────────────────────────────────────────────────────"

  local -A installed=()
  fetch_installed_crds installed

  local -a missing=() found=()
  for crd in "${expected[@]}"; do
    if [[ -n "${installed[$crd]+_}" ]]; then
      found+=("$crd")
    else
      missing+=("$crd")
    fi
  done

  for crd in "${found[@]}";   do echo "  ✅ $crd"; done
  for crd in "${missing[@]}"; do echo "  ❌ $crd  (missing)"; done

  echo "──────────────────────────────────────────────────────────"

  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "✅ All ${#expected[@]} expected CRDs are present."
    return 0
  else
    echo "❌ ${#missing[@]} of ${#expected[@]} CRDs are missing." >&2
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
