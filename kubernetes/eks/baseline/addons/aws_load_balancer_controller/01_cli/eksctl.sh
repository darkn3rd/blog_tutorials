
# * [Install AWS Load Balancer Controller with Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)

LBC_HELM_CHART_VERSION="3.4.0"
LBC_IAM_POLICY="https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
K8S_GATEWAY_API_CRDS=(
    https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
    https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml
    https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml
)



curl -sOL $LBC_IAM_POLICY
# aws iam create-policy \
#     --policy-name AWSLoadBalancerControllerIAMPolicy \
#     --policy-document file://iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://<(curl -sL LBC_IAM_POLICY)

eksctl create iamserviceaccount \
    --cluster=$EKS_CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region $EKS_REGION \
    --approve

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# Gateway CRDs
kubectl apply --server-side --filename https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
kubectl apply --server-side --filename https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml
# AWS LBC Gateway CRDs
kubectl apply --server-side --filename https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml

helm upgrade \
  --install \
  --version $LBC_HELM_CHART_VERSION \
  aws-load-balancer-controller eks/aws-load-balancer-controller \
  --values - <<EOF
# values.yaml.tmpl
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


# Apparently not needed in newer versions of Helm
# wget https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
# kubectl apply -f crds.yaml

# https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/3613