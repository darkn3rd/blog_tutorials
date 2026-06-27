
#!/usr/bin/env bash
set -euo pipefail

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

AWS_ACCOUNT_ID="$(aws sts get-caller-identity \
  --query "Account" \
  --output text)"
VPC_ID="$(aws eks describe-cluster \
  --name "$EKS_CLUSTER_NAME" \
  --region "$EKS_REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)"

PROJ_PREFIX_LBC_URL="https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller"
PROJ_PREFIX_GW_URL="https://github.com/kubernetes-sigs/gateway-api"
CRD_STANDARD=$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/standard-install.yaml
CRD_EXPERIMENTAL=$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/experimental-install.yaml
CRD_LBC_GW=$PROJ_PREFIX_LBC_URL/refs/heads/main/config/crd/gateway/gateway-crds.yaml
LBC_HELM_CHART_VERSION="3.4.0"
LBC_IAM_POLICY="$PROJ_PREFIX_LBC_URL/v2.14.1/docs/install/iam_policy.json"

create_lbc_iam_policy() {
  echo "Checking for existing LBC IAM Policy..."
  if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    echo "✅ IAM Policy already exists. Skipping creation."
    return 0
  fi

  echo "Creating LBC IAM Policy (Injecting modern Gateway API requirements)..."
  # Fetch standard policy, then append the explicit attributes needed by Gateway API loops
  local BASE_POLICY
  BASE_POLICY=$(curl -sL "$LBC_IAM_POLICY")
  
  local AMENDED_POLICY
  AMENDED_POLICY=$(echo "$BASE_POLICY" | jq '.Statement += [{
    "Effect": "Allow",
    "Action": [
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:ModifyListenerAttributes"
    ],
    "Resource": "*"
  }]')

  aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document "$AMENDED_POLICY" || echo "Policy already exists, moving forward..."
}

create_lbc_irsa_association() {
  echo "Associating IAM Service Account via eksctl..."
  eksctl create iamserviceaccount \
    --cluster="$EKS_CLUSTER_NAME" \
    --namespace="kube-system" \
    --name="aws-load-balancer-controller" \
    --attach-policy-arn="arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy" \
    --override-existing-serviceaccounts \
    --region "$EKS_REGION" \
    --approve
    
  echo "Sleeping 15 seconds to allow AWS OIDC replication to settle..."
  sleep 15
}

add_helm_repo() {
  helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
  helm repo update eks
}

install_gateway_crds() {
  local channel="${1:-standard}"

  case "$channel" in
    standard)
      echo "Applying Gateway API standard CRDs..."
      kubectl apply --server-side --force-conflicts --filename \
        "$CRD_STANDARD"
      ;;
    experimental)
      echo "Applying Gateway API experimental CRDs..."
      kubectl apply --server-side --force-conflicts --filename \
        "$CRD_EXPERIMENTAL"
      ;;
    *)
      echo "Usage: install_gateway_crds [standard|experimental]" >&2
      return 1
      ;;
  esac

  echo "Applying AWS Load Balancer Controller Gateway CRDs..."
  kubectl apply --server-side --force-conflicts --filename \
    "$CRD_LBC_GW"
}

install_lbc_helm_chart() {
  echo "Upgrading/Installing AWS Load Balancer Controller Chart v$LBC_HELM_CHART_VERSION..."
  helm upgrade \
  --install \
  --version $LBC_HELM_CHART_VERSION \
  --namespace kube-system \
  aws-load-balancer-controller eks/aws-load-balancer-controller \
  --values - <<EOF
clusterName: "${EKS_CLUSTER_NAME}"
vpcId: "${VPC_ID}"
region: "${EKS_REGION}"

serviceAccount:
  create: false
  name: "aws-load-balancer-controller"

controllerConfig:
  featureGates:
    ALBGatewayAPI: true
    NLBGatewayAPI: true
    GatewayListenerSet: true
EOF

}

main() {
  create_lbc_iam_policy
  create_lbc_irsa_association
  install_gateway_crds experimental
  add_helm_repo
  install_lbc_helm_chart
}

main "$@"

