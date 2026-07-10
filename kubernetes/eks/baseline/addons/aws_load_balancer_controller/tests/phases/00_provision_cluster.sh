#!/usr/bin/env bash
# phases/00_provision_cluster.sh — provisions the EKS cluster shared by
# every case in this run. Run-scoped: call once before any case's phases,
# not once per case. Writes tests/logs/cluster.env for downstream phases.
#
# Required env: CLUSTER_PROVISIONER_ROOT (path to the directory containing
# 01_eksctl/02_awscli_eksctl/03_terraform_eksctl/04_terraform_native/
# 05_terraform_modules - machine-specific, not stored in matrix.yaml).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }
# shellcheck source=../../scripts/lib/bash_version.sh
source "$TESTS_DIR/../scripts/lib/bash_version.sh"
verify_bash

# Every line of output gets a UTC timestamp prefix - cluster provisioning is
# the slowest single step in this framework (~15-20min), and it's the one
# calling terraform directly rather than through an already-wrapped leaf
# script, so it wouldn't otherwise get timestamps at all.
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

# shellcheck source=../lib/yaml.sh
source "$TESTS_DIR/lib/yaml.sh"
verify_yq

: "${CLUSTER_PROVISIONER_ROOT:?CLUSTER_PROVISIONER_ROOT is required - path to the directory containing 01_eksctl/02_awscli_eksctl/03_terraform_eksctl/04_terraform_native/05_terraform_modules}"

PROVISIONER="$(matrix_cluster_field provisioner)"
EKS_VERSION="$(matrix_cluster_field eks_version)"
EKS_REGION="${EKS_REGION:-$(matrix_cluster_field eks_region)}"
DATESTAMP="$(date +%Y%m%d%H%M%S)"
CLUSTER_NAME="testcluster-${DATESTAMP}"
TFVARS_FILE="test_${DATESTAMP}.tfvars"

provisioner_dir_for() {
  case "$1" in
    eksctl) echo "01_eksctl" ;;
    awscli-eksctl) echo "02_awscli_eksctl" ;;
    terraform-eksctl) echo "03_terraform_eksctl" ;;
    terraform-native) echo "04_terraform_native" ;;
    terraform-modules) echo "05_terraform_modules" ;;
    *) die "Unknown cluster.provisioner '$1' in matrix.yaml." ;;
  esac
}

# The only fully implemented provisioner - follow this shape for the others.
# Uses a datestamped var-file (test_<datestamp>.tfvars) passed via
# -var-file rather than writing terraform.tfvars directly - this directory
# may already have its own terraform.tfvars for manual/non-test use (it
# does: eks_cluster_name = "modcluster"), and overwriting that in place
# would clobber it and leave no record of what a given test run actually
# used.
provision_terraform_modules() {
  local dir="$CLUSTER_PROVISIONER_ROOT/05_terraform_modules"
  [[ -d "$dir" ]] || die "$dir not found - check CLUSTER_PROVISIONER_ROOT."

  cat > "$dir/$TFVARS_FILE" <<EOF
eks_version      = "${EKS_VERSION}"
eks_cluster_name = "${CLUSTER_NAME}"
eks_region       = "${EKS_REGION}"
EOF

  (cd "$dir" && terraform init -input=false -no-color && terraform apply -var-file="$TFVARS_FILE" -auto-approve -no-color)

  KUBECONFIG_PATH="$HOME/.kube/aws/${EKS_REGION}.${CLUSTER_NAME}.yaml"
  echo "==> Writing kubeconfig to $KUBECONFIG_PATH..."
  mkdir -p "$(dirname "$KUBECONFIG_PATH")"
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$EKS_REGION" --kubeconfig "$KUBECONFIG_PATH"
}

provision_not_implemented() {
  die "cluster.provisioner '$PROVISIONER' has no provisioning logic yet in $(basename "$0") - only terraform-modules is implemented. Fill in the $(provisioner_dir_for "$PROVISIONER") case following provision_terraform_modules() as a template."
}

echo "==> Provisioning cluster '$CLUSTER_NAME' via '$PROVISIONER'..."
case "$PROVISIONER" in
  terraform-modules) provision_terraform_modules ;;
  eksctl|awscli-eksctl|terraform-eksctl|terraform-native) provision_not_implemented ;;
  *) die "Unknown cluster.provisioner '$PROVISIONER' in matrix.yaml." ;;
esac

: "${KUBECONFIG_PATH:?provisioner '$PROVISIONER' did not set KUBECONFIG_PATH}"

mkdir -p "$TESTS_DIR/logs"
cat > "$TESTS_DIR/logs/cluster.env" <<EOF
EKS_CLUSTER_NAME=${CLUSTER_NAME}
EKS_REGION=${EKS_REGION}
CLUSTER_PROVISIONER=${PROVISIONER}
KUBECONFIG=${KUBECONFIG_PATH}
TF_VAR_FILE=${TFVARS_FILE}
EOF

echo "✅ Cluster '$CLUSTER_NAME' provisioned. State written to logs/cluster.env"
