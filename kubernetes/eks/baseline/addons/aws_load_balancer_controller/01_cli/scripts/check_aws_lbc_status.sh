#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0")

Surveys an existing AWS Load Balancer Controller installation and reports:
  - IAM authentication mechanism in use (IRSA, Pod Identity, or a policy
    attached directly to the worker node's IAM role)
  - Gateway API readiness (CRDs installed + controller feature gates)
  - Helm chart version (if Helm-managed) and running controller image version

This is read-only - it does not modify the cluster or AWS account.

Options:
  -h, --help   Show this help message and exit

Required environment variables:
  EKS_CLUSTER_NAME   Name of the target EKS cluster
  EKS_REGION         AWS region the cluster is in
  AWS_PROFILE        AWS CLI profile to use

Optional environment variables:
  DEPLOYMENT_NAME    Controller deployment name. Default: aws-load-balancer-controller
  SA_NAME            ServiceAccount name. Default: aws-load-balancer-controller
  SA_NAMESPACE       Namespace the controller runs in. Default: kube-system
  HELM_RELEASE_NAME  Helm release name to look up. Default: aws-load-balancer-controller
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
  esac
done

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-aws-load-balancer-controller}"
SA_NAME="${SA_NAME:-aws-load-balancer-controller}"
SA_NAMESPACE="${SA_NAMESPACE:-kube-system}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-aws-load-balancer-controller}"
LBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

GATEWAY_API_CRDS=(
  "gatewayclasses.gateway.networking.k8s.io"
  "gateways.gateway.networking.k8s.io"
  "httproutes.gateway.networking.k8s.io"
  "grpcroutes.gateway.networking.k8s.io"
  "tcproutes.gateway.networking.k8s.io"
  "tlsroutes.gateway.networking.k8s.io"
  "udproutes.gateway.networking.k8s.io"
  "referencegrants.gateway.networking.k8s.io"
  "listenersets.gateway.networking.k8s.io"
)

# UDPRoute is checked/reported above but deliberately excluded here: AWS LBC's
# ALBGatewayAPI/NLBGatewayAPI controllers don't reconcile UDPRoute, so its
# absence shouldn't affect the readiness verdict.
GATEWAY_API_REQUIRED_CRDS=(
  "gatewayclasses.gateway.networking.k8s.io"
  "gateways.gateway.networking.k8s.io"
  "httproutes.gateway.networking.k8s.io"
  "grpcroutes.gateway.networking.k8s.io"
  "tcproutes.gateway.networking.k8s.io"
  "tlsroutes.gateway.networking.k8s.io"
  "referencegrants.gateway.networking.k8s.io"
  "listenersets.gateway.networking.k8s.io"
)

verify_binaries() {
  echo "Checking required local CLI tools..."
  local missing_tools=()
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
    echo "Please verify that your active KUBECONFIG context is correct." >&2
    exit 1
  fi
  echo "✅ Cluster connection verified: $(kubectl config current-context)"
}

verify_requirements() {
  verify_binaries kubectl aws jq helm
  verify_kubernetes_connectivity
}

check_controller_installed() {
  echo
  echo "==> Checking for AWS Load Balancer Controller deployment..."
  if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$SA_NAMESPACE" &>/dev/null; then
    echo "❌ Deployment '$SA_NAMESPACE/$DEPLOYMENT_NAME' not found."
    echo "The AWS Load Balancer Controller does not appear to be installed."
    return 1
  fi

  local ready
  ready="$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null || true)"
  echo "✅ Found deployment $SA_NAMESPACE/$DEPLOYMENT_NAME (ready: ${ready:-unknown})"
}

# Third fallback auth path: no IRSA annotation, no Pod Identity association -
# check whether the underlying EC2 node's own instance profile role has the
# LBC policy attached (an older/simpler pattern with no per-pod IAM binding).
check_node_iam_role() {
  echo "  Checking whether the LBC policy is attached directly to the node's IAM role..."

  local node_name
  node_name="$(kubectl get pods -n "$SA_NAMESPACE" -l app.kubernetes.io/name=aws-load-balancer-controller \
    -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)"

  if [[ -z "$node_name" ]]; then
    echo "  Could not determine controller pod's node (no running pods found)."
    return 0
  fi

  local provider_id instance_id
  provider_id="$(kubectl get node "$node_name" -o jsonpath='{.spec.providerID}' 2>/dev/null || true)"
  instance_id="${provider_id##*/}"

  if [[ -z "$instance_id" || "$instance_id" == "$provider_id" ]]; then
    echo "  Node '$node_name' has no EC2 instance ID (possibly Fargate) - skipping."
    return 0
  fi

  local profile_arn
  profile_arn="$(aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --region "$EKS_REGION" \
    --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
    --output text 2>/dev/null || true)"

  if [[ -z "$profile_arn" || "$profile_arn" == "None" ]]; then
    echo "  No instance profile found for instance $instance_id."
    return 0
  fi

  local profile_name role_name
  profile_name="${profile_arn##*/}"
  role_name="$(aws iam get-instance-profile \
    --instance-profile-name "$profile_name" \
    --query "InstanceProfile.Roles[0].RoleName" \
    --output text 2>/dev/null || true)"

  if [[ -z "$role_name" || "$role_name" == "None" ]]; then
    echo "  Could not resolve IAM role from instance profile '$profile_name'."
    return 0
  fi

  local has_policy
  has_policy="$(aws iam list-attached-role-policies \
    --role-name "$role_name" \
    --query "AttachedPolicies[?PolicyName=='${LBC_POLICY_NAME}'].PolicyName" \
    --output text 2>/dev/null || true)"

  if [[ -n "$has_policy" ]]; then
    echo "  ✅ Node role '$role_name' (instance $instance_id) has $LBC_POLICY_NAME attached."
    NODE_ROLE_NAME="$role_name"
    NODE_ROLE_HAS_POLICY="true"
  else
    echo "  Node role '$role_name' does NOT have $LBC_POLICY_NAME attached."
    NODE_ROLE_HAS_POLICY="false"
  fi
}

determine_auth_mode() {
  echo
  echo "==> Determining IAM authentication mechanism..."

  local sa_role_arn
  sa_role_arn="$(kubectl get sa "$SA_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || true)"

  if [[ -n "$sa_role_arn" ]]; then
    echo "  ✅ IRSA detected - ServiceAccount annotated with role: $sa_role_arn"
    AUTH_MODE="irsa"
    AUTH_ROLE_ARN="$sa_role_arn"
    return 0
  fi

  local assoc_id
  assoc_id="$(aws eks list-pod-identity-associations \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --namespace "$SA_NAMESPACE" \
    --service-account "$SA_NAME" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null || true)"

  if [[ -n "$assoc_id" && "$assoc_id" != "None" ]]; then
    local role_arn
    role_arn="$(aws eks describe-pod-identity-association \
      --cluster-name "$EKS_CLUSTER_NAME" \
      --region "$EKS_REGION" \
      --association-id "$assoc_id" \
      --query "association.roleArn" \
      --output text 2>/dev/null || true)"
    echo "  ✅ Pod Identity detected - association bound to role: $role_arn"
    AUTH_MODE="pod-identity"
    AUTH_ROLE_ARN="$role_arn"
    return 0
  fi

  echo "  No IRSA annotation or Pod Identity association found."
  check_node_iam_role

  if [[ "${NODE_ROLE_HAS_POLICY:-false}" == "true" ]]; then
    AUTH_MODE="node-iam-role"
    AUTH_ROLE_ARN="$NODE_ROLE_NAME"
  else
    echo "  ⚠️  Could not determine how the controller obtains AWS credentials."
    AUTH_MODE="unknown"
    AUTH_ROLE_ARN=""
  fi
}

check_gateway_api_crds() {
  echo
  echo "==> Checking Gateway API CRDs..."
  MISSING_CRDS=()
  MISSING_REQUIRED_CRDS=()
  for crd in "${GATEWAY_API_CRDS[@]}"; do
    if kubectl get crd "$crd" &>/dev/null; then
      local versions
      versions="$(kubectl get crd "$crd" -o jsonpath='{.spec.versions[*].name}' 2>/dev/null)"
      echo "  ✅ $crd (versions served: $versions)"
    else
      echo "  ❌ $crd not installed"
      MISSING_CRDS+=("$crd")

      for required_crd in "${GATEWAY_API_REQUIRED_CRDS[@]}"; do
        if [[ "$crd" == "$required_crd" ]]; then
          MISSING_REQUIRED_CRDS+=("$crd")
          break
        fi
      done
    fi
  done
}

check_controller_feature_gates() {
  echo
  echo "==> Checking controller feature gates..."
  local args
  args="$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null || true)"

  local feature_gates
  feature_gates="$(echo "$args" | grep -oE -- '--feature-gates=[^ "]*' | head -1 | sed 's/--feature-gates=//')"

  if [[ -z "$feature_gates" ]]; then
    echo "  No --feature-gates argument found on the controller."
    ALB_GATEWAY_API="false"
    NLB_GATEWAY_API="false"
    LISTENER_SET_GATE="false"
    return 0
  fi

  echo "  Raw: --feature-gates=$feature_gates"
  [[ "$feature_gates" == *"ALBGatewayAPI=true"* ]] && ALB_GATEWAY_API="true" || ALB_GATEWAY_API="false"
  [[ "$feature_gates" == *"NLBGatewayAPI=true"* ]] && NLB_GATEWAY_API="true" || NLB_GATEWAY_API="false"
  [[ "$feature_gates" == *"GatewayListenerSet=true"* ]] && LISTENER_SET_GATE="true" || LISTENER_SET_GATE="false"

  echo "    ALBGatewayAPI:      $ALB_GATEWAY_API"
  echo "    NLBGatewayAPI:      $NLB_GATEWAY_API"
  echo "    GatewayListenerSet: $LISTENER_SET_GATE"
}

check_helm_release() {
  echo
  echo "==> Checking Helm release..."

  local helm_json
  helm_json="$(helm list -n "$SA_NAMESPACE" --filter "^${HELM_RELEASE_NAME}\$" -o json 2>/dev/null || echo '[]')"

  if [[ "$(echo "$helm_json" | jq 'length')" -eq 0 ]]; then
    echo "  Not Helm-managed (no release '$HELM_RELEASE_NAME' found in namespace $SA_NAMESPACE)."
    HELM_CHART_VERSION=""
    HELM_APP_VERSION=""
    return 0
  fi

  HELM_CHART_VERSION="$(echo "$helm_json" | jq -r '.[0].chart')"
  HELM_APP_VERSION="$(echo "$helm_json" | jq -r '.[0].app_version')"
  local helm_status
  helm_status="$(echo "$helm_json" | jq -r '.[0].status')"

  echo "  ✅ Helm release: $HELM_CHART_VERSION (app_version: $HELM_APP_VERSION, status: $helm_status)"
}

check_controller_image_version() {
  echo
  echo "==> Checking controller image version..."
  local image
  image="$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"

  if [[ -z "$image" ]]; then
    echo "  Could not read controller image."
    CONTROLLER_IMAGE=""
    CONTROLLER_IMAGE_TAG=""
    return 0
  fi

  CONTROLLER_IMAGE="$image"
  CONTROLLER_IMAGE_TAG="${image##*:}"
  echo "  ✅ Controller image: $image"
}

print_summary() {
  echo
  echo "========================================"
  echo " AWS Load Balancer Controller Status"
  echo "========================================"
  echo "Deployment:          $SA_NAMESPACE/$DEPLOYMENT_NAME"
  echo "Controller version:  ${CONTROLLER_IMAGE_TAG:-unknown}"
  echo "Controller image:    ${CONTROLLER_IMAGE:-unknown}"
  if [[ -n "${HELM_CHART_VERSION:-}" ]]; then
    echo "Helm chart:          $HELM_CHART_VERSION (app_version: $HELM_APP_VERSION)"
  else
    echo "Helm chart:          not Helm-managed"
  fi

  echo
  echo "IAM authentication:  $AUTH_MODE"
  case "$AUTH_MODE" in
    irsa) echo "  Role: $AUTH_ROLE_ARN (via IRSA)" ;;
    pod-identity) echo "  Role: $AUTH_ROLE_ARN (via Pod Identity)" ;;
    node-iam-role) echo "  Role: $AUTH_ROLE_ARN attached directly to the node's instance profile (no per-pod IAM binding)" ;;
    *) echo "  Could not determine how the controller obtains AWS credentials." ;;
  esac

  echo
  echo "Gateway API readiness:"
  echo "  CRDs missing: ${#MISSING_CRDS[@]} / ${#GATEWAY_API_CRDS[@]}"
  if [[ ${#MISSING_CRDS[@]} -gt 0 ]]; then
    printf '    - %s\n' "${MISSING_CRDS[@]}"
  fi
  echo "  Note: UDPRoute is not reconciled by AWS LBC ${CONTROLLER_IMAGE_TAG:-<unknown version>} (ALBGatewayAPI/NLBGatewayAPI don't use it), so its absence doesn't affect the readiness verdict below."
  echo "  ALBGatewayAPI feature gate:      ${ALB_GATEWAY_API:-unknown}"
  echo "  NLBGatewayAPI feature gate:      ${NLB_GATEWAY_API:-unknown}"
  echo "  GatewayListenerSet feature gate: ${LISTENER_SET_GATE:-unknown}"

  if [[ ${#MISSING_REQUIRED_CRDS[@]} -eq 0 && "${ALB_GATEWAY_API:-false}" == "true" && "${NLB_GATEWAY_API:-false}" == "true" ]]; then
    echo "  ✅ Gateway API ready (ALB + NLB)"
  else
    echo "  ⚠️  Gateway API not fully ready - see details above"
  fi
}

main() {
  verify_requirements
  check_controller_installed || exit 1
  determine_auth_mode
  check_gateway_api_crds
  check_controller_feature_gates
  check_helm_release
  check_controller_image_version
  print_summary
}

main "$@"
