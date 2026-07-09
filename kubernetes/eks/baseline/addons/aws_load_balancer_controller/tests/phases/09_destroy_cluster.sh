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
  (cd "$dir" && terraform destroy -var-file="$TF_VAR_FILE" -auto-approve)
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
