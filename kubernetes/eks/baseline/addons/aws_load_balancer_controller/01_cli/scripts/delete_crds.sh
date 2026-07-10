#!/usr/bin/env bash
# delete_crds.sh — Remove Gateway API CRDs from the cluster.
#
# Usage:
#   delete_crds.sh --channel <standard|experimental> --source <gateway-api|aws-gateway|all> [options]
#
# Options:
#   -c, --channel     Channel of the Gateway API manifests used during install.
#                     One of: standard, experimental  (default: experimental)
#   -s, --source      Which CRD group(s) to delete.
#                     One of: gateway-api, aws-gateway, all  (default: all)
#   -y, --yes         Skip the confirmation prompt and delete immediately.
#       --dry-run     Print what would be deleted without making any changes.
#   -h, --help        Show this help message.
#
# Exit codes:
#   0  All targeted CRDs were deleted (or were already absent).
#   1  One or more deletes failed, or a usage/connectivity error occurred.
#
# WARNING: Deleting CRDs removes all custom resources of those types cluster-wide.
#          This operation is irreversible without a backup.
#
# Requires: bash >= 4.3 (enforced at startup; aborts immediately otherwise)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash_version.sh
source "$SCRIPT_DIR/lib/bash_version.sh"
# shellcheck source=lib/crd_lists.sh
source "$SCRIPT_DIR/lib/crd_lists.sh"

die() { echo "❌ $*" >&2; exit 1; }

verify_bash

# ── Helpers ───────────────────────────────────────────────────────────────────

usage() {
  # Print contiguous leading comment block (lines 2–N until first blank/code line)
  awk '/^#!/{next} /^#/{sub(/^# ?/,""); print; next} /^[[:space:]]*$/{next} {exit}' "$0"
  exit 0
}

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

# confirm_deletion <crds...>
# Prints a summary of what will be deleted and prompts the user to confirm.
confirm_deletion() {
  local -a crds=("$@")
  echo ""
  echo "⚠️  The following ${#crds[@]} CRD(s) will be permanently deleted:"
  echo "    (All custom resources of these types will be removed cluster-wide.)"
  echo ""
  for crd in "${crds[@]}"; do echo "    🗑️  $crd"; done
  echo ""
  read -r -p "Type 'yes' to confirm: " answer
  if [[ "$answer" != "yes" ]]; then
    echo "Aborted. No changes were made."
    exit 0
  fi
}

# ── Core logic ────────────────────────────────────────────────────────────────

delete_crds() {
  local channel="$1"
  local source="$2"
  local dry_run="$3"   # "true" | "false"
  local skip_confirm="$4"  # "true" | "false"

  local -a expected=()
  resolve_crds "$channel" "$source" expected || exit 1

  local -A installed=()
  fetch_installed_crds installed

  # Partition into present (will act on) and absent (will skip)
  local -a targets=() absent=()
  for crd in "${expected[@]}"; do
    if [[ -n "${installed[$crd]+_}" ]]; then
      targets+=("$crd")
    else
      absent+=("$crd")
    fi
  done

  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "✅ Nothing to delete — none of the expected CRDs are installed."
    return 0
  fi

  # Confirmation gate (skipped in dry-run; --yes bypasses prompt)
  if [[ "$dry_run" == "true" ]]; then
    echo "ℹ️  Dry-run mode — no changes will be made."
  elif [[ "$skip_confirm" != "true" ]]; then
    confirm_deletion "${targets[@]}"
  fi

  echo ""
  echo "Deleting CRDs  [channel: $channel]  [source: $source]"
  echo "──────────────────────────────────────────────────────────"

  local -a kubectl_flags=()
  [[ "$dry_run" == "true" ]] && kubectl_flags+=(--dry-run=client)

  local -a deleted=() failed=()
  for crd in "${targets[@]}"; do
    if kubectl delete crd "$crd" "${kubectl_flags[@]}" 2>/dev/null; then
      echo "  🗑️  $crd — deleted"
      deleted+=("$crd")
    else
      echo "  ❌ $crd — delete failed" >&2
      failed+=("$crd")
    fi
  done

  for crd in "${absent[@]}"; do
    echo "  ⚠️  $crd — not found, skipped"
  done

  echo "──────────────────────────────────────────────────────────"

  local dry_run_label=""
  [[ "$dry_run" == "true" ]] && dry_run_label=" (dry-run)"

  echo "Summary${dry_run_label}: ${#deleted[@]} deleted, ${#absent[@]} skipped, ${#failed[@]} failed."

  [[ ${#failed[@]} -eq 0 ]] && return 0 || return 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

main() {
  local channel="experimental"
  local source="all"
  local dry_run="false"
  local skip_confirm="false"

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
      -y|--yes)
        skip_confirm="true"
        shift
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      -h|--help) usage ;;
      *) die "Unknown argument '$1'. Pass --help for usage." ;;
    esac
  done

  verify_kubectl
  delete_crds "$channel" "$source" "$dry_run" "$skip_confirm"
}

main "$@"
