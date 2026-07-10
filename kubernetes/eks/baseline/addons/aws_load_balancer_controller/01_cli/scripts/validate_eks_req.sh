#!/usr/bin/env bash
# Requires: bash >= 4.3 (enforced at startup; aborts immediately otherwise)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash_version.sh
source "$SCRIPT_DIR/lib/bash_version.sh"

die() { echo "❌ $*" >&2; exit 1; }

verify_bash

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    echo "  [PASS] $label"
    ((PASS++))
  else
    echo "  [FAIL] $label"
    ((FAIL++))
  fi
}

check_with_detail() {
  local label="$1"
  local result="$2"
  local pass="$3"
  if [[ "$pass" == "true" ]]; then
    echo "  [PASS] $label — $result"
    ((PASS++))
  else
    echo "  [FAIL] $label — $result"
    ((FAIL++))
  fi
}

echo "==> Validating EKS cluster: $EKS_CLUSTER_NAME (region: $EKS_REGION)"
echo ""

# ---- OIDC Provider ----
echo "--- OIDC Provider ---"
OIDC_ISSUER="$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" \
  --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null || true)"

if [[ -n "$OIDC_ISSUER" && "$OIDC_ISSUER" != "None" ]]; then
  OIDC_ID="${OIDC_ISSUER##*/}"
  PROVIDER_EXISTS="$(aws iam list-open-id-connect-providers --query \
    "OpenIDConnectProviderList[?ends_with(Arn, '/$OIDC_ID')]" --output text 2>/dev/null || true)"
  if [[ -n "$PROVIDER_EXISTS" ]]; then
    check_with_detail "OIDC provider registered in IAM" "$OIDC_ID" "true"
  else
    check_with_detail "OIDC provider registered in IAM" "issuer exists but no IAM provider for $OIDC_ID" "false"
  fi
else
  check_with_detail "OIDC provider registered in IAM" "no OIDC issuer on cluster" "false"
fi

echo ""

# ---- EKS Pod Identity Agent ----
echo "--- Pod Identity Addon ---"
POD_IDENTITY_STATUS="$(aws eks describe-addon --cluster-name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" \
  --addon-name eks-pod-identity-agent --query 'addon.status' --output text 2>/dev/null || true)"

if [[ "$POD_IDENTITY_STATUS" == "ACTIVE" ]]; then
  check_with_detail "eks-pod-identity-agent addon" "ACTIVE" "true"
else
  check_with_detail "eks-pod-identity-agent addon" "${POD_IDENTITY_STATUS:-not installed}" "false"
fi

echo ""

# ---- VPC CNI Addon ----
echo "--- VPC CNI Addon ---"
VPC_CNI_STATUS="$(aws eks describe-addon --cluster-name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" \
  --addon-name vpc-cni --query 'addon.status' --output text 2>/dev/null || true)"

if [[ "$VPC_CNI_STATUS" == "ACTIVE" ]]; then
  check_with_detail "vpc-cni addon" "ACTIVE" "true"
else
  check_with_detail "vpc-cni addon" "${VPC_CNI_STATUS:-not installed}" "false"
fi

# Check VPC CNI uses IRSA or Pod Identity (not node-level)
VPC_CNI_SA_ROLE="$(aws eks describe-addon --cluster-name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" \
  --addon-name vpc-cni --query 'addon.serviceAccountRoleArn' --output text 2>/dev/null || true)"

VPC_CNI_POD_IDENTITY="$(aws eks list-pod-identity-associations --cluster-name "$EKS_CLUSTER_NAME" \
  --region "$EKS_REGION" --namespace kube-system --service-account aws-node \
  --query 'associations[0].associationId' --output text 2>/dev/null || true)"

if [[ -n "$VPC_CNI_POD_IDENTITY" && "$VPC_CNI_POD_IDENTITY" != "None" ]]; then
  check_with_detail "vpc-cni auth" "Pod Identity association: $VPC_CNI_POD_IDENTITY" "true"
elif [[ -n "$VPC_CNI_SA_ROLE" && "$VPC_CNI_SA_ROLE" != "None" ]]; then
  check_with_detail "vpc-cni auth" "IRSA role: ${VPC_CNI_SA_ROLE##*/}" "true"
else
  check_with_detail "vpc-cni auth" "no IRSA or Pod Identity configured (likely using node-level privileges)" "false"
fi

echo ""

# ---- Subnet Tagging ----
echo "--- Subnet Tagging ---"
VPC_ID="$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)"

ALL_SUBNETS="$(aws ec2 describe-subnets --region "$EKS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" --output json)"

# Public subnets: tagged with kubernetes.io/role/elb = 1
PUBLIC_TAGGED="$(echo "$ALL_SUBNETS" | jq '[.Subnets[] |
  select(.Tags // [] | map(select(.Key == "kubernetes.io/role/elb" and .Value == "1")) | length > 0) |
  .SubnetId] | length')"

if [[ "$PUBLIC_TAGGED" -gt 0 ]]; then
  check_with_detail "Public subnets tagged (kubernetes.io/role/elb=1)" "$PUBLIC_TAGGED subnet(s)" "true"
else
  check_with_detail "Public subnets tagged (kubernetes.io/role/elb=1)" "none found" "false"
fi

# Private subnets: tagged with kubernetes.io/role/internal-elb = 1
PRIVATE_TAGGED="$(echo "$ALL_SUBNETS" | jq '[.Subnets[] |
  select(.Tags // [] | map(select(.Key == "kubernetes.io/role/internal-elb" and .Value == "1")) | length > 0) |
  .SubnetId] | length')"

if [[ "$PRIVATE_TAGGED" -gt 0 ]]; then
  check_with_detail "Private subnets tagged (kubernetes.io/role/internal-elb=1)" "$PRIVATE_TAGGED subnet(s)" "true"
else
  check_with_detail "Private subnets tagged (kubernetes.io/role/internal-elb=1)" "none found" "false"
fi

echo ""

# ---- Summary ----
TOTAL=$((PASS + FAIL))
echo "==> Results: $PASS/$TOTAL passed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "    $FAIL check(s) failed — resolve before installing AWS Load Balancer Controller."
  exit 1
fi
echo "    Cluster is ready for AWS Load Balancer Controller."
