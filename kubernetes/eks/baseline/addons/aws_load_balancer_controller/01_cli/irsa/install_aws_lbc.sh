
#!/usr/bin/env bash
set -euo pipefail

# Required Variables
: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

# Globals
HELM_CHART_VERSION="3.4.0"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
ROLE_NAME="AmazonEKSLoadBalancerControllerRole"

verify_binaries() {
  echo "Checking required local CLI tools..."
  local missing_tools=()
  
  # Loop through all arguments passed to the function
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing_tools+=("$tool")
    fi
  done

  if [ ${#missing_tools[@]} -ne 0 ]; then
    echo "❌ Error: Missing required CLI utilities." >&2
    echo "Please install the following tools and retry: ${missing_tools[*]}" >&2
    exit 1
  fi
  echo "✅ All CLI tools available."
}

verify_kubernetes_connectivity() {
  echo "Checking Kubernetes cluster connection..."
  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Error: Cannot connect to the Kubernetes cluster." >&2
    echo "Please verify that your active KUBECONFIG context is correct and your AWS credentials are valid." >&2
    exit 1
  fi

  echo "✅ Cluster connection verified: $(kubectl config current-context)"
} 

verify_aws_connectivity() {
  echo "Checking AWS CLI connectivity and credentials..."
  
  # Captures any error messages from a failed authentication attempt
  local auth_error
  if ! auth_error=$(aws sts get-caller-identity --query "Arn" --output text 2>&1 >/dev/null); then
    echo "❌ Error: AWS authentication failed using profile '${AWS_PROFILE:-default}'." >&2
    echo "Details: $auth_error" >&2
    echo "Please run 'aws sso login' or check your environment credentials." >&2
    exit 1
  fi

  echo "✅ AWS connection verified successfully."
}

verify_requirements() {
  verify_binaries "$@"
  verify_kubernetes_connectivity
  verify_aws_connectivity
}

create_lbc_iam_policy() {
  local policy_arn="${1:?policy_arn is required}"
  local lbc_iam_policy="https://raw.githubusercontent.com/kubernetes-sigs/"\
"aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
  
  echo "Checking for existing LBC IAM Policy..."
  if aws iam get-policy --policy-arn "$policy_arn" >/dev/null 2>&1; then
    echo "✅ IAM Policy already exists. Skipping creation."
    return 0
  fi

  echo "Creating LBC IAM Policy (Injecting modern Gateway API requirements)..."
  # Fetch standard policy, then append the explicit attributes needed by Gateway API loops
  local base_policy amended_policy
  base_policy=$(curl -sL "$lbc_iam_policy")
  
  amended_policy=$(echo "$base_policy" | jq '.Statement += [{
    "Effect": "Allow",
    "Action": [
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:ModifyListenerAttributes"
    ],
    "Resource": "*"
  }]')

  aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document "$amended_policy"
}

create_lbc_irsa_association() {
  local policy_arn="${1:?policy_arn is required}"
  local target_mode="${2:?mode is required}"

  if [ "$target_mode" = "aws-cli" ]; then
    create_lbc_irsa_association_awscli "$policy_arn"
  else
    # Your classic eksctl code path wrapped into a descriptive sub-call
    create_lbc_irsa_association_eksctl "$policy_arn"
  fi
}

create_lbc_irsa_association_eksctl() {
  local policy_arn="${1:?policy_arn is required}"

  echo "Associating IAM Service Account via eksctl..."
  eksctl create iamserviceaccount \
    --cluster="$EKS_CLUSTER_NAME" \
    --namespace="kube-system" \
    --name="$SERVICE_ACCOUNT_NAME" \
    --attach-policy-arn="$policy_arn" \
    --override-existing-serviceaccounts \
    --region "$EKS_REGION" \
    --approve
    
  echo "Sleeping 15 seconds to allow AWS OIDC replication to settle..."
  sleep 15
}

create_lbc_irsa_association_awscli() {
  local policy_arn="${1:?policy_arn is required}"
  
  echo "Discovering OIDC issuer configuration..."
  local oidc_url oidc_provider
  oidc_url=$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --query "cluster.identity.oidc.issuer" \
    --output text)
  
  oidc_provider="${oidc_url#https://}"

  echo "Generating temporary IAM trust policy document..."
  local trust_policy
  trust_policy=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$oidc_provider"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${oidc_provider}:sub": "system:serviceaccount:kube-system:$SERVICE_ACCOUNT_NAME",
          "${oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
)

  echo "Configuring IAM Role and policy attachments..."
  if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "⚠️ IAM Role '$ROLE_NAME' exists. Updating trust relationship..."
    aws iam update-assume-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-document "$trust_policy"
  else
    aws iam create-role \
      --role-name "$ROLE_NAME" \
      --assume-role-policy-document "$trust_policy"
  fi

  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$policy_arn"

  echo "Deploying annotated Kubernetes ServiceAccount..."
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: $SERVICE_ACCOUNT_NAME
  name: $SERVICE_ACCOUNT_NAME
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME
EOF
}

add_helm_repo() {
  helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
  helm repo update eks
}

install_gateway_crds() {
  local channel="${1:-standard}"

  # Base prefixes broken down to fit within narrow viewports
  local prefix_gw="https://github.com/kubernetes-sigs/gateway-api"

  # Manifest URLs constructed cleanly using the local prefixes
  local crd_standard="$prefix_gw/releases/download/v1.5.0/standard-install.yaml"
  local crd_experimental="$prefix_gw/releases/download/v1.5.0/"\
"experimental-install.yaml"
  local crd_lbc_gw="https://raw.githubusercontent.com/kubernetes-sigs/"\
"aws-load-balancer-controller/refs/heads/main/config/crd/gateway/"\
"gateway-crds.yaml"

  case "$channel" in
    standard)
      echo "Applying Gateway API standard CRDs..."
      kubectl apply --server-side --force-conflicts --filename \
        "$crd_standard"
      ;;
    experimental)
      echo "Applying Gateway API experimental CRDs..."
      kubectl apply --server-side --force-conflicts --filename \
        "$crd_experimental"
      ;;
    *)
      echo "Usage: install_gateway_crds [standard|experimental]" >&2
      return 1
      ;;
  esac

  echo "Applying AWS Load Balancer Controller Gateway CRDs..."
  kubectl apply --server-side --force-conflicts --filename \
    "$crd_lbc_gw"
}

install_lbc_helm_chart() {
  local vpc_id="${1:?vpc_id is required}"
  local chart_version="${2:?chart_version is required}"

  echo "Upgrading/Installing AWS Load Balancer Controller Chart v${chart_version}..."
  helm upgrade \
  --install \
  --version $chart_version \
  --namespace kube-system \
  aws-load-balancer-controller eks/aws-load-balancer-controller \
  --values - <<EOF
clusterName: "${EKS_CLUSTER_NAME}"
vpcId: "${vpc_id}"
region: "${EKS_REGION}"

serviceAccount:
  create: false
  name: "${SERVICE_ACCOUNT_NAME}"

controllerConfig:
  featureGates:
    ALBGatewayAPI: true
    NLBGatewayAPI: true
    GatewayListenerSet: true
EOF

}

main() {
  local mode="${1:-eksctl}"

  # Determine which tools are strictly required based on the mode
  local required_tools=("aws" "kubectl" "helm" "jq" "curl")
  if [ "$mode" = "eksctl" ]; then
    required_tools+=("eksctl")
  elif [ "$mode" != "aws-cli" ]; then
    echo "❌ Error: Invalid mode '$mode'. Use 'eksctl' or 'aws-cli'." >&2
    exit 1
  fi

  verify_requirements "${required_tools[@]}"

  echo "Discovering cluster infrastructure details..."
  AWS_ACCOUNT_ID="$(aws sts get-caller-identity \
    --query "Account" \
    --output text)"
  VPC_ID="$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)"

  POLICY_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME"
  
  create_lbc_iam_policy "$POLICY_ARN" "$mode"
  create_lbc_irsa_association "$POLICY_ARN"
  install_gateway_crds experimental
  add_helm_repo
  install_lbc_helm_chart "$VPC_ID" "$HELM_CHART_VERSION"
}

main "$@"

