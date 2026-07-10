#!/usr/bin/env bash
# lib/aws.sh — Shared AWS CLI helpers.
# Source this file; do not execute it directly.
#
# Requires: aws, jq
# Assumes:  die() is defined by the sourcing script.

# verify_aws_connectivity
# Exits via die() if AWS credentials are invalid or unreachable.
verify_aws_connectivity() {
  echo "Checking AWS credentials..."
  local err
  if ! err=$(aws sts get-caller-identity --query "Arn" --output text 2>&1 >/dev/null); then
    die "AWS authentication failed: $err\nRun 'aws sso login' or check your environment credentials."
  fi
  echo "✅ AWS credentials verified."
}

# get_account_id → stdout
# Resolves the caller's AWS account ID via STS.
get_account_id() {
  aws sts get-caller-identity --query "Account" --output text
}

# fetch_live_policy <policy-arn> → stdout (JSON policy document)
# Fetches the default version of a managed IAM policy document.
fetch_live_policy() {
  local policy_arn="${1:?policy_arn is required}"

  local version_id
  version_id=$(aws iam get-policy \
    --policy-arn "$policy_arn" \
    --query "Policy.DefaultVersionId" \
    --output text 2>/dev/null) \
    || die "Policy not found or not accessible: $policy_arn"

  aws iam get-policy-version \
    --policy-arn "$policy_arn" \
    --version-id "$version_id" \
    --query "PolicyVersion.Document" \
    --output json 2>/dev/null \
    || die "Could not retrieve policy version $version_id for: $policy_arn"
}

# get_role_attached_policy_arns <role-name> <nameref-array>
# Populates nameref array with the ARNs of all policies attached to the role.
get_role_attached_policy_arns() {
  local role_name="${1:?role_name is required}"
  local -n _arns="${2:?nameref is required}"
  _arns=()

  local raw
  raw=$(aws iam list-attached-role-policies \
    --role-name "$role_name" \
    --query "AttachedPolicies[].PolicyArn" \
    --output json 2>/dev/null) \
    || die "Could not list attached policies for role: $role_name"

  while IFS= read -r arn; do
    [[ -n "$arn" ]] && _arns+=("$arn")
  done < <(echo "$raw" | jq -r '.[]')
}

# role_exists <role-name> → 0 if exists, 1 if not
role_exists() {
  local role_name="${1:?role_name is required}"
  aws iam get-role --role-name "$role_name" >/dev/null 2>&1
}
