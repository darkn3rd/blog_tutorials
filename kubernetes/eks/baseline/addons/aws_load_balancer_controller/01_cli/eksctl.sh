
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
LBC_HELM_CHART_VERSION="3.4.0"
LBC_IAM_POLICY="$PROJ_PREFIX_LBC_URL/v2.14.1/docs/install/iam_policy.json"

K8S_GATEWAY_API_CRDS=(
    $PROJ_PREFIX_GW_URL/releases/download/v1.5.0/standard-install.yaml
    $PROJ_PREFIX_GW_URL/releases/download/v1.5.0/experimental-install.yaml
    $PROJ_PREFIX_LBC_URL/refs/heads/main/config/crd/gateway/gateway-crds.yaml
)

create_lbc_iam_policy() {
  aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://<(curl -sL $LBC_IAM_POLICY)
}

create_lbc_irsa_association() {
  eksctl create iamserviceaccount \
    --cluster=$EKS_CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region $EKS_REGION \
    --approve
}

add_helm_repo() {
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update eks
}

install_gateway_crds() {
  for URL in ${K8S_GATEWAY_API_CRDS[@]}; do 
    kubectl apply --server-side --filename $URL
  done
}

install_lbc_helm_chart() {
  helm upgrade \
  --install \
  --version $LBC_HELM_CHART_VERSION \
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
  install_gateway_crds
  add_helm_repo
  install_lbc_helm_chart
}

