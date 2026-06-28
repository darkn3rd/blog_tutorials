#!/usr/bin/env bash
set -euo pipefail

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query "Account" --output text)"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

PROJ_PREFIX_LBC_URL="https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller"
PROJ_PREFIX_GW_URL="https://github.com/kubernetes-sigs/gateway-api"

K8S_GATEWAY_API_CRDS=(
    "$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/standard-install.yaml"
    "$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/experimental-install.yaml"
    "$PROJ_PREFIX_LBC_URL/refs/heads/main/config/crd/gateway/gateway-crds.yaml"
)

SA_NAME="aws-load-balancer-controller"
SA_NAMESPACE="${SA_NAMESPACE:-kube-system}"

deprovision_aws_load_balancers() {
  echo "==> Deprovisioning AWS load balancer resources..."

  # ALB Ingresses
  local ingresses
  ingresses="$(kubectl get ingress --all-namespaces -o json 2>/dev/null || echo '{"items":[]}')"
  local alb_ingresses
  alb_ingresses="$(echo "$ingresses" | jq -r '
    .items[] |
    select(
      .metadata.annotations["kubernetes.io/ingress.class"] == "alb" or
      .spec.ingressClassName == "alb"
    ) | "\(.metadata.namespace)/\(.metadata.name)"')"
  for entry in $alb_ingresses; do
    local ns="${entry%%/*}"
    local name="${entry##*/}"
    echo "  Deleting ALB Ingress: $ns/$name"
    kubectl delete ingress "$name" -n "$ns" --ignore-not-found=true
  done

  # NLB Services (type LoadBalancer with NLB annotation)
  local services
  services="$(kubectl get svc --all-namespaces -o json 2>/dev/null || echo '{"items":[]}')"
  local nlb_services
  nlb_services="$(echo "$services" | jq -r '
    .items[] |
    select(
      .spec.type == "LoadBalancer" and (
        .metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-type"] == "nlb" or
        .metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-type"] == "external" or
        .metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-type"] == "nlb-ip"
      )
    ) | "\(.metadata.namespace)/\(.metadata.name)"')"
  for entry in $nlb_services; do
    local ns="${entry%%/*}"
    local name="${entry##*/}"
    echo "  Deleting NLB Service: $ns/$name"
    kubectl delete svc "$name" -n "$ns" --ignore-not-found=true
  done

  # Gateway API resources (Gateways with gatewayclass managed by LBC)
  if kubectl api-resources --api-group=gateway.networking.k8s.io &>/dev/null 2>&1; then
    local gateways
    gateways="$(kubectl get gateways --all-namespaces -o json 2>/dev/null || echo '{"items":[]}')"
    local lbc_gateways
    lbc_gateways="$(echo "$gateways" | jq -r '
      .items[] |
      select(
        .spec.gatewayClassName == "amazon-vpc-lattice" or
        .spec.gatewayClassName == "aws-alb" or
        .spec.gatewayClassName == "aws-nlb"
      ) | "\(.metadata.namespace)/\(.metadata.name)"')"
    for entry in $lbc_gateways; do
      local ns="${entry%%/*}"
      local name="${entry##*/}"
      echo "  Deleting Gateway: $ns/$name"
      kubectl delete gateway "$name" -n "$ns" --ignore-not-found=true
    done

    # HTTPRoutes and TCPRoutes that reference deleted gateways
    for kind in httproute tcproute grpcroute tlsroute udproute; do
      local routes
      routes="$(kubectl get "$kind" --all-namespaces -o json 2>/dev/null || echo '{"items":[]}')"
      local route_entries
      route_entries="$(echo "$routes" | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"')"
      for entry in $route_entries; do
        local ns="${entry%%/*}"
        local name="${entry##*/}"
        echo "  Deleting $kind: $ns/$name"
        kubectl delete "$kind" "$name" -n "$ns" --ignore-not-found=true
      done
    done
  fi

  echo "  Waiting for load balancers to deprovision..."
  sleep 30
}

uninstall_lbc_helm_chart() {
  echo "==> Removing AWS Load Balancer Controller Helm release..."
  if helm status aws-load-balancer-controller --namespace kube-system &>/dev/null; then
    helm uninstall aws-load-balancer-controller --namespace kube-system
  else
    echo "  Helm release not found, skipping."
  fi
}

uninstall_gateway_crds() {
  echo "==> Deleting Gateway API CRDs..."
  for url in "${K8S_GATEWAY_API_CRDS[@]}"; do
    kubectl delete --filename "$url" --ignore-not-found=true 2>/dev/null || true
  done
}

extract_iam_role_from_sa() {
  echo "==> Extracting IAM role from ServiceAccount annotation..."
  IAM_ROLE_ARN="$(kubectl get sa "$SA_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || true)"
  if [[ -n "$IAM_ROLE_ARN" ]]; then
    IAM_ROLE_NAME="${IAM_ROLE_ARN##*/}"
    echo "  Found IAM role: $IAM_ROLE_NAME"
  else
    echo "  No IAM role annotation found on ServiceAccount."
    IAM_ROLE_NAME=""
  fi
}

delete_service_account() {
  echo "==> Deleting ServiceAccount $SA_NAMESPACE/$SA_NAME..."
  kubectl delete sa "$SA_NAME" -n "$SA_NAMESPACE" --ignore-not-found=true
}

delete_iam_role() {
  if [[ -z "${IAM_ROLE_NAME:-}" ]]; then
    echo "==> No IAM role to delete, skipping."
    return 0
  fi

  echo "==> Deleting IAM Role: $IAM_ROLE_NAME..."

  if ! aws iam get-role --role-name "$IAM_ROLE_NAME" &>/dev/null; then
    echo "  IAM Role not found, skipping."
    return 0
  fi

  # Detach all managed policies from the role
  local policies
  policies="$(aws iam list-attached-role-policies --role-name "$IAM_ROLE_NAME" \
    --query 'AttachedPolicies[].PolicyArn' --output text)"
  for policy_arn in $policies; do
    echo "  Detaching policy: $policy_arn"
    aws iam detach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn "$policy_arn"
  done

  # Delete inline policies
  local inline
  inline="$(aws iam list-role-policies --role-name "$IAM_ROLE_NAME" \
    --query 'PolicyNames[]' --output text)"
  for policy_name in $inline; do
    echo "  Deleting inline policy: $policy_name"
    aws iam delete-role-policy --role-name "$IAM_ROLE_NAME" --policy-name "$policy_name"
  done

  # Delete instance profiles
  local profiles
  profiles="$(aws iam list-instance-profiles-for-role --role-name "$IAM_ROLE_NAME" \
    --query 'InstanceProfiles[].InstanceProfileName' --output text)"
  for profile in $profiles; do
    echo "  Removing role from instance profile: $profile"
    aws iam remove-role-from-instance-profile --role-name "$IAM_ROLE_NAME" \
      --instance-profile-name "$profile"
  done

  aws iam delete-role --role-name "$IAM_ROLE_NAME"
  echo "  IAM Role deleted."
}

delete_iam_policy() {
  echo "==> Deleting IAM Policy: $POLICY_ARN..."

  if ! aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "  IAM Policy not found, skipping."
    return 0
  fi

  # Detach from any remaining entities (belt-and-suspenders after role deletion)
  local roles
  roles="$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" \
    --query 'PolicyRoles[].RoleName' --output text)"
  for role in $roles; do
    echo "  Detaching from role: $role"
    aws iam detach-role-policy --role-name "$role" --policy-arn "$POLICY_ARN"
  done

  local users
  users="$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" \
    --query 'PolicyUsers[].UserName' --output text)"
  for user in $users; do
    echo "  Detaching from user: $user"
    aws iam detach-user-policy --user-name "$user" --policy-arn "$POLICY_ARN"
  done

  local groups
  groups="$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" \
    --query 'PolicyGroups[].GroupName' --output text)"
  for group in $groups; do
    echo "  Detaching from group: $group"
    aws iam detach-group-policy --group-name "$group" --policy-arn "$POLICY_ARN"
  done

  # Delete non-default policy versions
  local versions
  versions="$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
    --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)"
  for ver in $versions; do
    echo "  Deleting policy version: $ver"
    aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$ver"
  done

  aws iam delete-policy --policy-arn "$POLICY_ARN"
  echo "  IAM Policy deleted."
}

delete_eksctl_stack() {
  local stack_name="eksctl-${EKS_CLUSTER_NAME}-addon-iamserviceaccount-${SA_NAMESPACE}-${SA_NAME}"
  echo "==> Deleting CloudFormation stack: $stack_name (if exists)..."
  if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$EKS_REGION" &>/dev/null; then
    aws cloudformation delete-stack --stack-name "$stack_name" --region "$EKS_REGION"
    echo "  Waiting for stack deletion..."
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$EKS_REGION"
    echo "  Stack deleted."
  else
    echo "  Stack not found, skipping."
  fi
}

main() {
  deprovision_aws_load_balancers
  uninstall_lbc_helm_chart
  uninstall_gateway_crds
  extract_iam_role_from_sa
  delete_service_account
  delete_iam_role
  delete_iam_policy
  delete_eksctl_stack
  echo "Cleanup completed successfully!"
}

main
