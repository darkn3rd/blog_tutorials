#!/usr/bin/env bash
# phases/01_preflight.sh — tool/connectivity checks, then verifies the
# cluster is in a clean state BEFORE this case starts. Catching leftover
# state from a previous failed run here, rather than compounding on top of
# it, is the whole point of running this before every case.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"
: "${INSTALL_METHOD:?INSTALL_METHOD is required}"

echo "==> Checking required tools..."
required_tools=(aws kubectl helm jq yq)
[[ "$INSTALL_METHOD" == "cli-eksctl" || "$INSTALL_METHOD" == "python-exec-cli-eksctl" ]] && required_tools+=(eksctl)
[[ "$INSTALL_METHOD" == "terraform" ]] && required_tools+=(terraform)
[[ "$INSTALL_METHOD" == python-* ]] && required_tools+=(python3)
missing=()
for tool in "${required_tools[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
[[ ${#missing[@]} -eq 0 ]] || die "Missing required tools: ${missing[*]}"
echo "✅ All required tools available."

echo "==> Checking AWS connectivity..."
aws sts get-caller-identity >/dev/null || die "AWS authentication failed."
echo "✅ AWS connectivity verified."

echo "==> Checking cluster connectivity..."
kubectl cluster-info >/dev/null 2>&1 || die "Cannot connect to the Kubernetes cluster. Check KUBECONFIG."
echo "✅ Cluster connectivity verified: $(kubectl config current-context)"

echo "==> Verifying cluster is in a clean state before this case starts..."
if ! verify_clean "$INSTALL_METHOD"; then
  die "Cluster is not clean before this case started - a previous run likely left resources behind. Investigate before re-running."
fi
echo "✅ Cluster is clean."
