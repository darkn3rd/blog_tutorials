#!/usr/bin/env bash
set -euo pipefail

# 1. Validation Pre-flights
: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

# 2. Extract Active Environment IDs
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query "Account" --output text)"

PROJ_PREFIX_LBC_URL="https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller"
PROJ_PREFIX_GW_URL="https://github.com/kubernetes-sigs/gateway-api"

K8S_GATEWAY_API_CRDS=(
    "$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/standard-install.yaml"
    "$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/experimental-install.yaml"
    "$PROJ_PREFIX_LBC_URL/refs/heads/main/config/crd/gateway/gateway-crds.yaml"
)

uninstall_lbc_helm_chart() {
  echo "Removing AWS Load Balancer Controller Helm release..."
  if helm status aws-load-balancer-controller --namespace kube-system &>/dev/null; then
    helm uninstall aws-load-balancer-controller --namespace kube-system
  else
    echo "Helm release not found, skipping..."
  fi
}

uninstall_gateway_crds() {
  echo "Deleting Gateway API CRDs..."
  for URL in "${K8S_GATEWAY_API_CRDS[@]}"; do
    # Using '|| true' ensures the script doesn't exit if some CRDs were already deleted
    kubectl delete --filename "$URL" --ignore-not-found=true || true
  done
}

delete_lbc_irsa_association() {
  echo "Deleting IAM Service Account via eksctl..."
  eksctl delete iamserviceaccount \
    --cluster="$EKS_CLUSTER_NAME" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --region "$EKS_REGION" || echo "Service account association not found, skipping..."
}

delete_lbc_iam_policy() {
  local POLICY_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy"
  echo "Deleting IAM Policy: $POLICY_ARN..."
  
  if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    aws iam delete-policy --policy-arn "$POLICY_ARN"
  else
    echo "IAM Policy not found, skipping..."
  fi
}

main() {
  # Order matters: Strip the app software before cutting the infrastructure legs out from under it
  uninstall_lbc_helm_chart
  uninstall_gateway_crds
  delete_lbc_irsa_association
  delete_lbc_iam_policy
  echo "🎉 Cleanup completed successfully!"
}

main
