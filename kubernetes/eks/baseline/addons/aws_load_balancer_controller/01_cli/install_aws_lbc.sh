#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [tool] [auth]

Installs the AWS Load Balancer Controller onto an existing EKS cluster.

Arguments:
  tool   Which CLI provisions the IAM binding: eksctl or aws-cli. Default: eksctl
  auth   Authentication mechanism: irsa or pod-identity. Default: irsa

Options:
  -h, --help   Show this help message and exit

Required environment variables:
  EKS_CLUSTER_NAME   Name of the target EKS cluster
  EKS_REGION         AWS region the cluster is in
  AWS_PROFILE        AWS CLI profile to use

Examples:
  EKS_CLUSTER_NAME=my-cluster EKS_REGION=us-east-2 AWS_PROFILE=default $(basename "$0")
  EKS_CLUSTER_NAME=my-cluster EKS_REGION=us-east-2 AWS_PROFILE=default $(basename "$0") aws-cli pod-identity
EOF
}

# Handled before the required-variable checks below so --help works even
# without EKS_CLUSTER_NAME/EKS_REGION/AWS_PROFILE set.
for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "❌ $*" >&2; exit 1; }
# shellcheck source=eks_terraform_project/scripts/lib/bash_version.sh
source "$SCRIPT_DIR/eks_terraform_project/scripts/lib/bash_version.sh"
verify_bash

# Every line of output gets a UTC timestamp prefix from here on (after
# --help, so a plain --help invocation stays clean) - this script can run
# for a couple of minutes, and figuring out which step actually took the
# time by eyeballing unmarked output was a repeated pain point.
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
  local tool_mode="${1:?tool_mode is required}"

  local required_tools=("aws" "kubectl" "helm" "jq" "curl")
  if [ "$tool_mode" = "eksctl" ]; then
    required_tools+=("eksctl")
  fi

  verify_binaries "${required_tools[@]}"
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

verify_oidc_provider() {
  echo "Checking for an IAM OIDC provider associated with the cluster..."

  local oidc_url
  oidc_url=$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --query "cluster.identity.oidc.issuer" \
    --output text)

  OIDC_PROVIDER="${oidc_url#https://}"

  if ! aws iam get-open-id-connect-provider \
      --open-id-connect-provider-arn "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER" \
      >/dev/null 2>&1; then
    echo "❌ Error: No IAM OIDC provider is associated with this cluster." >&2
    echo "IRSA requires one. Create it first, e.g.:" >&2
    echo "  eksctl utils associate-iam-oidc-provider --cluster \"$EKS_CLUSTER_NAME\" --region \"$EKS_REGION\" --approve" >&2
    exit 1
  fi

  echo "✅ IAM OIDC provider found: $OIDC_PROVIDER"
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

  # OIDC_PROVIDER is set by verify_oidc_provider, which must run before this
  echo "Generating temporary IAM trust policy document..."
  local trust_policy
  trust_policy=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:$SERVICE_ACCOUNT_NAME",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
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

verify_pod_identity_addon() {
  echo "Checking for the EKS Pod Identity Agent addon..."
  if ! aws eks describe-addon \
      --cluster-name "$EKS_CLUSTER_NAME" \
      --region "$EKS_REGION" \
      --addon-name eks-pod-identity-agent >/dev/null 2>&1; then
    echo "❌ Error: The 'eks-pod-identity-agent' addon is not installed on this cluster." >&2
    echo "Pod Identity requires it. Install it first, e.g.:" >&2
    echo "  aws eks create-addon --cluster-name \"$EKS_CLUSTER_NAME\" --region \"$EKS_REGION\" --addon-name eks-pod-identity-agent" >&2
    exit 1
  fi

  echo "✅ Pod Identity Agent addon is installed."
}

# Pod Identity doesn't annotate the ServiceAccount (the binding lives in EKS,
# not on the object), but Helm is invoked with serviceAccount.create=false,
# so it still needs to exist.
ensure_service_account() {
  echo "Ensuring Kubernetes ServiceAccount exists..."
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: $SERVICE_ACCOUNT_NAME
  name: $SERVICE_ACCOUNT_NAME
  namespace: kube-system
EOF
}

create_lbc_pod_identity_association() {
  local policy_arn="${1:?policy_arn is required}"
  local target_mode="${2:?mode is required}"

  # Precondition (addon must exist) is checked earlier in main() via verify_pod_identity_addon
  ensure_service_account

  if [ "$target_mode" = "aws-cli" ]; then
    create_lbc_pod_identity_association_awscli "$policy_arn"
  else
    create_lbc_pod_identity_association_eksctl "$policy_arn"
  fi
}

create_lbc_pod_identity_association_eksctl() {
  local policy_arn="${1:?policy_arn is required}"

  echo "Checking for an existing Pod Identity association..."
  local existing_count
  existing_count=$(eksctl get podidentityassociation \
    --cluster="$EKS_CLUSTER_NAME" \
    --namespace=kube-system \
    --service-account-name="$SERVICE_ACCOUNT_NAME" \
    --region "$EKS_REGION" \
    --output json 2>/dev/null | jq 'length')

  if [ "${existing_count:-0}" != "0" ]; then
    echo "✅ Pod Identity association already exists. Skipping creation."
    return 0
  fi

  echo "Creating Pod Identity association via eksctl..."
  eksctl create podidentityassociation \
    --cluster="$EKS_CLUSTER_NAME" \
    --namespace=kube-system \
    --service-account-name="$SERVICE_ACCOUNT_NAME" \
    --permission-policy-arns="$policy_arn" \
    --region "$EKS_REGION"
}

create_lbc_pod_identity_association_awscli() {
  local policy_arn="${1:?policy_arn is required}"

  echo "Generating Pod Identity trust policy document..."
  local trust_policy
  trust_policy=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
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

  echo "Checking for an existing Pod Identity association..."
  local assoc_id
  assoc_id=$(aws eks list-pod-identity-associations \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --namespace kube-system \
    --service-account "$SERVICE_ACCOUNT_NAME" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null || true)

  if [ -n "$assoc_id" ] && [ "$assoc_id" != "None" ]; then
    echo "✅ Pod Identity association already exists. Skipping creation."
    return 0
  fi

  echo "Creating Pod Identity association..."
  aws eks create-pod-identity-association \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --namespace kube-system \
    --service-account "$SERVICE_ACCOUNT_NAME" \
    --role-arn "arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME"
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

validate_modes() {
  local tool_mode="${1:?tool_mode is required}"
  local auth_mode="${2:?auth_mode is required}"

  if [ "$tool_mode" != "eksctl" ] && [ "$tool_mode" != "aws-cli" ]; then
    echo "❌ Error: Invalid tool '$tool_mode'. Use 'eksctl' or 'aws-cli'." >&2
    echo >&2
    usage >&2
    exit 1
  fi
  if [ "$auth_mode" != "irsa" ] && [ "$auth_mode" != "pod-identity" ]; then
    echo "❌ Error: Invalid auth mode '$auth_mode'. Use 'irsa' or 'pod-identity'." >&2
    echo >&2
    usage >&2
    exit 1
  fi
}

discover_cluster_info() {
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
}

verify_auth_prerequisites() {
  local auth_mode="${1:?auth_mode is required}"

  echo "Verifying prerequisites for '$auth_mode' authentication..."
  if [ "$auth_mode" = "pod-identity" ]; then
    verify_pod_identity_addon
  else
    verify_oidc_provider
  fi
}

create_lbc_iam_binding() {
  local policy_arn="${1:?policy_arn is required}"
  local auth_mode="${2:?auth_mode is required}"
  local tool_mode="${3:?tool_mode is required}"

  echo "Provisioning IAM binding via '$auth_mode' using '$tool_mode'..."
  if [ "$auth_mode" = "pod-identity" ]; then
    create_lbc_pod_identity_association "$policy_arn" "$tool_mode"
  else
    create_lbc_irsa_association "$policy_arn" "$tool_mode"
  fi
}

main() {
  local tool_mode="${1:-eksctl}"
  local auth_mode="${2:-irsa}"

  validate_modes "$tool_mode" "$auth_mode"
  verify_requirements "$tool_mode"
  discover_cluster_info
  verify_auth_prerequisites "$auth_mode"
  create_lbc_iam_policy "$POLICY_ARN"
  create_lbc_iam_binding "$POLICY_ARN" "$auth_mode" "$tool_mode"
  install_gateway_crds experimental
  add_helm_repo
  install_lbc_helm_chart "$VPC_ID" "$HELM_CHART_VERSION"
}

main "$@"

