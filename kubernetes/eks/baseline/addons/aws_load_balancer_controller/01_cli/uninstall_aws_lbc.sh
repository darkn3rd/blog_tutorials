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

# Every Gateway API kind this script's CRD deletion removes. Since the CRDs
# themselves are being deleted wholesale regardless of who owns any given
# instance, every live instance of every one of these kinds is in scope for
# cleanup - there is no such thing as "not ours" here. This intentionally
# does NOT filter by GatewayClass name or controllerName: a live HTTPRoute
# attached to a Gateway named "fido" blocks the httproutes CRD's deletion
# exactly the same as one attached to a Gateway named "aws-alb-gateway".
GATEWAY_API_KINDS=(gateway httproute grpcroute tcproute tlsroute udproute referencegrant gatewayclass)
LBC_CONFIG_KINDS=(loadbalancerconfiguration targetgroupconfiguration listenerruleconfiguration)

# list_all_of_kind <kind> -> stdout, one "namespace/name" per line for
# namespaced kinds or "name" per line for cluster-scoped kinds (e.g.
# gatewayclass). Silent empty output if the kind's CRD isn't installed.
list_all_of_kind() {
  local kind="${1:?kind is required}"
  kubectl get "$kind" --all-namespaces -o json 2>/dev/null \
    | jq -r '.items[]? | if .metadata.namespace then "\(.metadata.namespace)/\(.metadata.name)" else .metadata.name end'
}

# delete_all_of_kind <kind> [label] - deletes every live instance of <kind>,
# printing each as it goes. [label] overrides the kind name in the log line
# (e.g. "ALB Ingress" instead of "ingress").
delete_all_of_kind() {
  local kind="${1:?kind is required}"
  local label="${2:-$kind}"
  local entry
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ "$entry" == */* ]]; then
      local ns="${entry%%/*}" name="${entry##*/}"
      echo "  Deleting $label: $ns/$name"
      kubectl delete "$kind" "$name" -n "$ns" --ignore-not-found=true
    else
      echo "  Deleting $label: $entry"
      kubectl delete "$kind" "$entry" --ignore-not-found=true
    fi
  done < <(list_all_of_kind "$kind")
}

# find_alb_ingresses -> stdout, one "namespace/name" per line
# Matched by IngressClass *controller* (ingress.k8s.aws/alb), not by an
# IngressClass literally named "alb" - the IngressClass name is arbitrary,
# same reasoning as GatewayClass below.
find_alb_ingresses() {
  local alb_classes
  alb_classes="$(kubectl get ingressclass -o json 2>/dev/null | jq -r '
    .items[]? | select(.spec.controller == "ingress.k8s.aws/alb") | .metadata.name')"
  local classes_json
  classes_json="$(printf '%s\n' "$alb_classes" | jq -R -s -c 'split("\n") | map(select(length > 0))')"

  kubectl get ingress --all-namespaces -o json 2>/dev/null | jq -r --argjson classes "$classes_json" '
    .items[] |
    select(
      (.metadata.annotations["kubernetes.io/ingress.class"] as $c | $c != null and ($classes | index($c) != null)) or
      (.spec.ingressClassName as $c | $c != null and ($classes | index($c) != null))
    ) | "\(.metadata.namespace)/\(.metadata.name)"'
}

# find_aws_lb_services -> stdout, one "namespace/name" per line
# Matched by the fixed annotation values / loadBalancerClass prefix the AWS
# LBC itself recognizes - these are not user-renameable, unlike class names.
find_aws_lb_services() {
  kubectl get svc --all-namespaces -o json 2>/dev/null | jq -r '
    .items[] |
    select(
      .spec.type == "LoadBalancer" and (
        (.metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-type"] as $t | $t == "nlb" or $t == "external" or $t == "nlb-ip") or
        ((.spec.loadBalancerClass // "") | startswith("service.k8s.aws/"))
      )
    ) | "\(.metadata.namespace)/\(.metadata.name)"'
}

deprovision_aws_load_balancers() {
  echo "==> Deprovisioning AWS load balancer resources..."

  local entry
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    local ns="${entry%%/*}" name="${entry##*/}"
    echo "  Deleting ALB Ingress: $ns/$name"
    kubectl delete ingress "$name" -n "$ns" --ignore-not-found=true
  done < <(find_alb_ingresses)

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    local ns="${entry%%/*}" name="${entry##*/}"
    echo "  Deleting LB Service: $ns/$name"
    kubectl delete svc "$name" -n "$ns" --ignore-not-found=true
  done < <(find_aws_lb_services)

  # Gateway API - wholesale (see GATEWAY_API_KINDS comment above).
  if kubectl api-resources --api-group=gateway.networking.k8s.io &>/dev/null 2>&1; then
    local kind
    for kind in "${GATEWAY_API_KINDS[@]}"; do
      delete_all_of_kind "$kind"
    done
  fi

  # LoadBalancerConfiguration/TargetGroupConfiguration/ListenerRuleConfiguration -
  # referenced by Gateways via parametersRef, not owned via ownerReference, so
  # deleting the Gateway above doesn't clean these up on its own.
  for kind in "${LBC_CONFIG_KINDS[@]}"; do
    if kubectl api-resources --api-group=gateway.k8s.aws 2>/dev/null | grep -qi "^${kind}"; then
      delete_all_of_kind "$kind"
    fi
  done

  # Poll rather than blindly sleep-and-hope: finalizer removal happens
  # asynchronously as the controller reconciles each deletion, so give it
  # real time and confirm rather than assuming 30s was enough.
  echo "  Waiting for load balancers to deprovision..."
  local elapsed=0 interval=10 timeout=120
  while (( elapsed < timeout )); do
    if detect_aws_load_balancers >/dev/null 2>&1; then
      echo "  Confirmed clean."
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  echo "❌ Timed out after ${timeout}s - resources are still present:" >&2
  detect_aws_load_balancers
  return 1
}

# detect_aws_load_balancers
# Sanity check: confirms nothing that would provision, reference, or block
# deletion of an AWS load balancer remains. Silent and returns 0 if clean.
# On failure, prints exactly what's left (kind + namespace/name) to stderr
# and returns 1. Callers must treat a non-zero return as fatal: deleting the
# Gateway API CRDs or uninstalling the Helm release while this reports
# uncleared resources will cascade onto them and hang, since the controller
# either won't exist (post-Helm-uninstall) or can't act (mid-CRD-deletion).
detect_aws_load_balancers() {
  local -a remaining=()
  local entry kind

  while IFS= read -r entry; do
    [[ -n "$entry" ]] && remaining+=("Ingress: $entry")
  done < <(find_alb_ingresses)

  while IFS= read -r entry; do
    [[ -n "$entry" ]] && remaining+=("Service: $entry")
  done < <(find_aws_lb_services)

  if kubectl api-resources --api-group=gateway.networking.k8s.io &>/dev/null 2>&1; then
    for kind in "${GATEWAY_API_KINDS[@]}"; do
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && remaining+=("$kind: $entry")
      done < <(list_all_of_kind "$kind")
    done
  fi

  for kind in "${LBC_CONFIG_KINDS[@]}"; do
    if kubectl api-resources --api-group=gateway.k8s.aws 2>/dev/null | grep -qi "^${kind}"; then
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && remaining+=("$kind: $entry")
      done < <(list_all_of_kind "$kind")
    fi
  done

  if [[ ${#remaining[@]} -gt 0 ]]; then
    echo "❌ ${#remaining[@]} resource(s) that provision or reference an AWS load balancer are still present:" >&2
    printf '     %s\n' "${remaining[@]}" >&2
    echo "  Refusing to delete Gateway API CRDs or uninstall the Helm release while these exist -" >&2
    echo "  both would cascade onto these objects and hang. Investigate (stuck finalizer? controller" >&2
    echo "  error? a resource this script doesn't know to look for?) and re-run." >&2
    return 1
  fi

  return 0
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

determine_auth_mode() {
  echo "==> Determining IAM binding type for ServiceAccount $SA_NAMESPACE/$SA_NAME..."

  local sa_role_arn
  sa_role_arn="$(kubectl get sa "$SA_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || true)"

  if [[ -n "$sa_role_arn" ]]; then
    echo "  ServiceAccount is annotated with an IAM role -> IRSA."
    AUTH_MODE="irsa"
    return 0
  fi

  # No annotation doesn't necessarily mean Pod Identity - verify a live
  # association actually exists rather than assuming.
  local assoc_id
  assoc_id="$(aws eks list-pod-identity-associations \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --namespace "$SA_NAMESPACE" \
    --service-account "$SA_NAME" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null || true)"

  if [[ -n "$assoc_id" && "$assoc_id" != "None" ]]; then
    echo "  Found an EKS Pod Identity association -> Pod Identity."
    AUTH_MODE="pod-identity"
    return 0
  fi

  echo "  No IRSA annotation or Pod Identity association found."
  AUTH_MODE=""
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

extract_iam_role_from_pod_identity() {
  echo "==> Extracting IAM role from Pod Identity association..."

  local assoc_id
  assoc_id="$(aws eks list-pod-identity-associations \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --namespace "$SA_NAMESPACE" \
    --service-account "$SA_NAME" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null || true)"

  if [[ -z "$assoc_id" || "$assoc_id" == "None" ]]; then
    echo "  No Pod Identity association found."
    POD_IDENTITY_ASSOCIATION_ID=""
    IAM_ROLE_NAME=""
    return 0
  fi

  POD_IDENTITY_ASSOCIATION_ID="$assoc_id"

  local role_arn
  role_arn="$(aws eks describe-pod-identity-association \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --association-id "$assoc_id" \
    --query "association.roleArn" \
    --output text 2>/dev/null || true)"

  if [[ -n "$role_arn" && "$role_arn" != "None" ]]; then
    IAM_ROLE_NAME="${role_arn##*/}"
    echo "  Found IAM role: $IAM_ROLE_NAME"
  else
    echo "  No IAM role found on Pod Identity association."
    IAM_ROLE_NAME=""
  fi
}

extract_iam_role_info() {
  case "$AUTH_MODE" in
    irsa) extract_iam_role_from_sa ;;
    pod-identity) extract_iam_role_from_pod_identity ;;
    *) IAM_ROLE_NAME="" ;;
  esac
}

delete_service_account() {
  echo "==> Deleting ServiceAccount $SA_NAMESPACE/$SA_NAME..."
  kubectl delete sa "$SA_NAME" -n "$SA_NAMESPACE" --ignore-not-found=true
}

delete_pod_identity_association() {
  if [[ -z "${POD_IDENTITY_ASSOCIATION_ID:-}" ]]; then
    echo "==> No Pod Identity association to delete, skipping."
    return 0
  fi

  echo "==> Deleting Pod Identity association: $POD_IDENTITY_ASSOCIATION_ID..."
  aws eks delete-pod-identity-association \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --association-id "$POD_IDENTITY_ASSOCIATION_ID"
  echo "  Pod Identity association deleted."
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

cfn_stack_exists() {
  local stack_name="${1:?stack_name is required}"
  aws cloudformation describe-stacks --stack-name "$stack_name" --region "$EKS_REGION" &>/dev/null
}

# Deletes a CloudFormation stack by name. Disables termination protection
# first if needed - eksctl enables it by default on stacks it creates, and
# delete-stack fails outright otherwise. Caller must have already confirmed
# the stack exists (via cfn_stack_exists).
delete_cfn_stack() {
  local stack_name="${1:?stack_name is required}"
  echo "==> Deleting CloudFormation stack: $stack_name..."

  local termination_protection
  termination_protection="$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$EKS_REGION" \
    --query 'Stacks[0].EnableTerminationProtection' --output text 2>/dev/null || true)"

  if [[ "$termination_protection" == "True" ]]; then
    echo "  Termination protection is enabled on this stack - disabling it first..."
    aws cloudformation update-termination-protection \
      --stack-name "$stack_name" \
      --region "$EKS_REGION" \
      --no-enable-termination-protection >/dev/null
  fi

  aws cloudformation delete-stack --stack-name "$stack_name" --region "$EKS_REGION"
  echo "  Waiting for stack deletion..."
  aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$EKS_REGION"
  echo "  Stack deleted."
}

# eksctl create iamserviceaccount / podidentityassociation each provision a
# CloudFormation stack to own the IAM role only when eksctl generated the role
# itself (no --role-arn/--attach-role-arn was passed). When that's the case,
# CloudFormation must be the one to delete the role - deleting it directly via
# the IAM API first (as this used to do) leaves the stack orphaned, unable to
# clean itself up. So: check for the stack first, and only fall back to a
# direct IAM role deletion when there isn't one (aws-cli-created roles).
delete_iam_role_or_stack() {
  local stack_name="${1:?stack_name is required}"

  if cfn_stack_exists "$stack_name"; then
    echo "==> IAM role is managed by eksctl via CloudFormation stack: $stack_name"
    delete_cfn_stack "$stack_name"
  else
    delete_iam_role
  fi
}

delete_iam_binding() {
  case "$AUTH_MODE" in
    irsa)
      delete_iam_role_or_stack "eksctl-${EKS_CLUSTER_NAME}-addon-iamserviceaccount-${SA_NAMESPACE}-${SA_NAME}"
      ;;
    pod-identity)
      delete_pod_identity_association
      delete_iam_role_or_stack "eksctl-${EKS_CLUSTER_NAME}-podidentityrole-${SA_NAMESPACE}-${SA_NAME}"
      ;;
    *)
      echo "==> No IAM binding detected, skipping IAM role/association cleanup."
      ;;
  esac
}

main() {
  # deprovision_aws_load_balancers() polls detect_aws_load_balancers()
  # internally and fails (non-zero, with an itemized list already printed)
  # if anything is still present after the timeout. CRD deletion and the
  # Helm uninstall both cascade onto/depend on a clean state - if it comes
  # back present, treat it as fatal and stop instead of walking into either
  # hang.
  if ! deprovision_aws_load_balancers; then
    echo "❌ Aborting: cluster is not in a clean state for CRD/Helm teardown." >&2
    exit 1
  fi

  # CRDs before Helm: deleting a CRD cascades to delete every live instance of
  # it first, and any instance still carrying an LBC-owned finalizer can only
  # have that finalizer cleared by the controller reconciling the deletion. If
  # Helm is uninstalled (killing the controller) first, any instance missed by
  # deprovision_aws_load_balancers() above hangs forever instead of failing.
  uninstall_gateway_crds
  uninstall_lbc_helm_chart
  determine_auth_mode
  extract_iam_role_info
  delete_service_account
  delete_iam_binding
  delete_iam_policy
  echo "Cleanup completed successfully!"
}

main
