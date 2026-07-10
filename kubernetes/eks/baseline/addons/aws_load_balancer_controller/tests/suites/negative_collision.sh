#!/usr/bin/env bash
# suites/negative_collision.sh — regression test for the stale-policy-
# collision bug this session hit (neg_test_01.sh pre-created a policy under
# LBC's name with unrelated eks:Describe* permissions; install_aws_lbc.sh's
# "already exists, skip" check then left the controller running with no
# real permissions).
#
# By the time this suite runs (phase 06, after install/validate/demos), the
# CORRECT policy/binding for this case already exists - there's no "before
# install" moment left in the fixed phase order to inject a real collision
# without a disruptive uninstall/reinstall cycle. Instead this tests the
# same underlying property surgically:
#   - cli-eksctl/cli-aws: temporarily push a bad IAM policy VERSION (the
#     same content class as neg_test_01.sh) as the default, confirm
#     validate_iam_policy.sh actually catches it, then restore the original
#     default version.
#   - terraform: temporarily detach the policy from the Terraform-managed
#     role out-of-band (the exact CloudFormation-drift bug class, just via
#     the AWS API instead of a competing tool), confirm `terraform plan
#     -detailed-exitcode` reports drift (exit 2), then reattach and confirm
#     plan is clean again.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${INSTALL_METHOD:?INSTALL_METHOD is required}"
: "${AUTH_MODE:?AUTH_MODE is required}"

BAD_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    }
  ]
}'

collision_via_bad_policy_version() {
  local account_id policy_arn original_version bad_version rc=0
  account_id="$(aws sts get-caller-identity --query Account --output text)"
  policy_arn="arn:aws:iam::${account_id}:policy/AWSLoadBalancerControllerIAMPolicy"

  original_version="$(aws iam get-policy --policy-arn "$policy_arn" --query 'Policy.DefaultVersionId' --output text)"
  [[ -n "$original_version" && "$original_version" != "None" ]] || die "Could not resolve current default policy version - is LBC actually installed?"

  echo "  Pushing a bad policy version as default (mirrors neg_test_01.sh's collision content)..."
  bad_version="$(aws iam create-policy-version --policy-arn "$policy_arn" \
    --policy-document "$BAD_POLICY_DOC" --set-as-default \
    --query 'PolicyVersion.VersionId' --output text)"

  echo "  Running validate_lbc, expecting it to FAIL..."
  if validate_lbc >/dev/null 2>&1; then
    echo "❌ validate_lbc passed against a known-bad policy - detection regressed." >&2
    rc=1
  else
    echo "  ✅ validate_lbc correctly failed."
  fi

  echo "  Restoring original policy version as default..."
  aws iam set-default-policy-version --policy-arn "$policy_arn" --version-id "$original_version"
  aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$bad_version"

  return $rc
}

collision_via_terraform_drift() {
  local tf_dir tfvars_file
  tf_dir="$(terraform_dir_for_auth_mode "$AUTH_MODE")"
  tfvars_file="$(tfvars_file_for_case)"
  local account_id policy_arn role_name rc=0
  account_id="$(aws sts get-caller-identity --query Account --output text)"
  policy_arn="arn:aws:iam::${account_id}:policy/AWSLoadBalancerControllerIAMPolicy"
  role_name="${EKS_CLUSTER_NAME}-aws-load-balancer-controller"

  echo "  Detaching the policy from the Terraform-managed role out-of-band..."
  aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"

  echo "  Running 'terraform plan -detailed-exitcode', expecting drift (exit 2)..."
  local plan_rc=0
  (cd "$tf_dir" && terraform plan -var-file="$tfvars_file" -detailed-exitcode -input=false -no-color >/dev/null 2>&1) || plan_rc=$?
  if [[ "$plan_rc" -eq 2 ]]; then
    echo "  ✅ terraform plan correctly detected drift."
  else
    echo "❌ terraform plan did not report drift (exit $plan_rc, expected 2) - drift detection regressed." >&2
    rc=1
  fi

  echo "  Reattaching the policy to restore state..."
  aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"

  local restore_rc=0
  (cd "$tf_dir" && terraform plan -var-file="$tfvars_file" -detailed-exitcode -input=false -no-color >/dev/null 2>&1) || restore_rc=$?
  if [[ "$restore_rc" -ne 0 ]]; then
    echo "❌ terraform plan still reports drift after restoring the attachment - suite left state dirty." >&2
    rc=1
  fi

  return $rc
}

case "$INSTALL_METHOD" in
  cli-eksctl|cli-aws) collision_via_bad_policy_version ;;
  terraform) collision_via_terraform_drift ;;
  *) die "Unknown install_method '$INSTALL_METHOD'." ;;
esac
