#!/usr/bin/env bash
# phases/09_destroy_cluster.sh — destroys the cluster provisioned by phase
# 00. Run-scoped: call once after all cases in this run have finished, not
# once per case. Reuses the exact test_<datestamp>.tfvars var-file phase 00
# wrote (recorded as TF_VAR_FILE in logs/cluster.env, no regeneration) so
# destroy targets exactly what was applied.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }
# shellcheck source=../../01_cli/scripts/lib/bash_version.sh
source "$TESTS_DIR/../01_cli/scripts/lib/bash_version.sh"
verify_bash

# Every line of output gets a UTC timestamp prefix - same reasoning as
# phase 00: this calls terraform directly, not through an already-wrapped
# leaf script.
# Also dedups repeated tool-progress lines (terraform "Still creating...
# [Ns elapsed]" heartbeats, eksctl repeated "waiting for..." lines) so a
# slow apply doesn't spam the terminal, while any genuinely new/changed
# line (a different resource, a different message) always prints
# immediately. Lines from this script itself (==>/status markers) print
# as-is; everything else is indented to show it's from the underlying
# tool, not this script.
_tool_output_filter() {
  local _lf_last="" _lf_last_ts=0
  while IFS= read -r _line; do
    local _lf_now _lf_norm
    _lf_now=$(date +%s)
    _lf_norm="$(printf '%s' "$_line" | sed -E \
      -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T? ?[0-9]{2}:[0-9]{2}:[0-9]{2}Z? *//' \
      -e 's/[0-9]+m[0-9]+s elapsed/Ns elapsed/' \
      -e 's/\[[0-9]+s elapsed\]/[Ns elapsed]/')"
    if [[ "$_lf_norm" == "$_lf_last" ]] && (( _lf_now - _lf_last_ts < 30 )); then
      continue
    fi
    _lf_last="$_lf_norm"; _lf_last_ts="$_lf_now"
    case "$_line" in
      "==>"*|"✅"*|"❌"*|"⚠️"*|"─────"*|"====="*|"")
        printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
      *)
        printf '[%s]     | %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
    esac
  done
}
exec > >(_tool_output_filter) 2>&1

: "${CLUSTER_PROVISIONER_ROOT:?CLUSTER_PROVISIONER_ROOT is required}"
[[ -f "$TESTS_DIR/logs/cluster.env" ]] || die "logs/cluster.env not found - was phase 00 (provision_cluster) run in this session?"
# shellcheck source=/dev/null
source "$TESTS_DIR/logs/cluster.env"
: "${CLUSTER_PROVISIONER:?CLUSTER_PROVISIONER not set in logs/cluster.env}"
: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME not set in logs/cluster.env}"
: "${TF_VAR_FILE:?TF_VAR_FILE not set in logs/cluster.env}"

destroy_terraform_modules() {
  local dir="$CLUSTER_PROVISIONER_ROOT/05_terraform_modules"
  [[ -f "$dir/$TF_VAR_FILE" ]] || die "$dir/$TF_VAR_FILE not found - nothing to destroy, or it was provisioned outside this framework."
  (cd "$dir" && terraform destroy -var-file="$TF_VAR_FILE" -auto-approve -no-color)
  rm -f "$dir/$TF_VAR_FILE"
}

destroy_not_implemented() {
  die "cluster.provisioner '$CLUSTER_PROVISIONER' has no destroy logic yet in $(basename "$0") - only terraform-modules is implemented."
}

echo "==> Destroying cluster '$EKS_CLUSTER_NAME' via '$CLUSTER_PROVISIONER'..."
case "$CLUSTER_PROVISIONER" in
  terraform-modules) destroy_terraform_modules ;;
  eksctl|awscli-eksctl|terraform-eksctl|terraform-native) destroy_not_implemented ;;
  *) die "Unknown provisioner '$CLUSTER_PROVISIONER' recorded in logs/cluster.env." ;;
esac

rm -f "$TESTS_DIR/logs/cluster.env"
echo "✅ Cluster destroyed."
