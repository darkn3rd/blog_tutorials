#!/usr/bin/env bash
# lib/role_discovery.sh — Finds the IAM role (and its attached policy) bound
# to a Kubernetes ServiceAccount, regardless of whether the binding was made
# via IRSA or EKS Pod Identity.
# Source this file; do not execute it directly.
#
# Requires: aws, kubectl
# Assumes:  die() is defined by the sourcing script;
#           service_account_exists() / get_service_account_annotation() are
#           available (from lib/k8s.sh);
#           get_role_attached_policy_arns() is available (from lib/aws.sh).

# get_pod_identity_role_arn <cluster-name> <namespace> <service-account> <region> → stdout
# Prints the role ARN of the EKS Pod Identity association for the given
# namespace/ServiceAccount, or nothing if no association exists.
#
# --region is required on both calls: EKS Pod Identity associations are
# region-scoped, and the AWS CLI's default region (from $AWS_DEFAULT_REGION,
# a profile, or ~/.aws/config) has no reason to match the target cluster's
# region -- get it wrong and these calls silently return nothing rather than
# erroring, which looks identical to "no association exists".
get_pod_identity_role_arn() {
  local cluster_name="${1:?cluster_name is required}"
  local namespace="${2:?namespace is required}"
  local sa_name="${3:?sa_name is required}"
  local region="${4:?region is required}"

  local association_id
  association_id=$(aws eks list-pod-identity-associations \
    --cluster-name "$cluster_name" \
    --namespace "$namespace" \
    --service-account "$sa_name" \
    --region "$region" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null) || true
  [[ -n "$association_id" && "$association_id" != "None" ]] || return 0

  aws eks describe-pod-identity-association \
    --cluster-name "$cluster_name" \
    --association-id "$association_id" \
    --region "$region" \
    --query "association.roleArn" \
    --output text 2>/dev/null || true
}

# find_role_arn <cluster-name> <namespace> <service-account> <region> → stdout
# Tries the IRSA role-arn annotation first (set identically by eksctl, the
# aws-cli install path, and the Terraform module -- it's the standard EKS
# Pod Identity Webhook contract, not something each tool invents
# independently), then falls back to an EKS Pod Identity association. Exits
# via die() if neither resolves to a role.
find_role_arn() {
  local cluster_name="${1:?cluster_name is required}"
  local namespace="${2:?namespace is required}"
  local sa_name="${3:?sa_name is required}"
  local region="${4:?region is required}"

  service_account_exists "$sa_name" "$namespace" \
    || die "ServiceAccount '$sa_name' not found in namespace '$namespace'."

  local role_arn
  role_arn=$(get_service_account_annotation "$sa_name" "$namespace" 'eks\.amazonaws\.com/role-arn')

  if [[ -z "$role_arn" ]]; then
    role_arn=$(get_pod_identity_role_arn "$cluster_name" "$namespace" "$sa_name" "$region")
  fi

  [[ -n "$role_arn" ]] \
    || die "ServiceAccount '$sa_name' is bound to a role via neither an IRSA role-arn annotation nor an EKS Pod Identity association in region '$region'."

  echo "$role_arn"
}

# find_attached_policy_arn <role-name> → stdout
# Returns the single IAM policy ARN attached to the role, whatever it's
# named. Dies if zero or more than one policy is attached -- in the
# more-than-one case that's ambiguous, so the caller should pass an explicit
# --policy-name instead of relying on discovery.
find_attached_policy_arn() {
  local role_name="${1:?role_name is required}"

  local -a attached_arns=()
  get_role_attached_policy_arns "$role_name" attached_arns

  case "${#attached_arns[@]}" in
    0) die "No IAM policies are attached to role '$role_name'." ;;
    1) echo "${attached_arns[0]}" ;;
    *)
      local joined
      joined=$(IFS=,; echo "${attached_arns[*]}")
      die "Role '$role_name' has ${#attached_arns[@]} policies attached ($joined) -- pass --policy-name to pick one explicitly."
      ;;
  esac
}
