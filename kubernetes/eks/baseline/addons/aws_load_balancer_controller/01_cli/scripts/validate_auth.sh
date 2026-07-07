#!/usr/bin/env bash
# validate_auth.sh — Verify the full IAM auth chain for the AWS Load
#                    Balancer Controller, whichever mechanism actually binds
#                    it:
#
#   ServiceAccount → IRSA annotation or Pod Identity association
#   → IAM role exists → policy attached → policy contents correct
#
# Usage:
#   validate_auth.sh [options]
#
# Options:
#   -s, --service-account  Kubernetes ServiceAccount name
#                          (default: aws-load-balancer-controller)
#   -n, --namespace        Kubernetes namespace to look in
#                          (default: kube-system)
#   -c, --cluster-name     EKS cluster name. Only needed if there's no IRSA
#                          annotation, to look up a Pod Identity association
#                          instead  (default: $EKS_CLUSTER_NAME)
#   -r, --region           AWS region the cluster lives in. Only needed if
#                          there's no IRSA annotation -- the Pod Identity
#                          lookup is region-scoped  (default: $EKS_REGION)
#   -p, --policy-name      IAM policy name to look for attached to the role.
#                          If omitted, whichever single policy is actually
#                          attached is used instead, regardless of its name.
#   -h, --help             Show this help message.
#
# Exit codes:
#   0  All auth chain checks passed.
#   1  One or more checks failed.
#
# Requires: bash >= 4.3 (enforced at startup; aborts immediately otherwise)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/bash_version.sh
source "$SCRIPT_DIR/lib/bash_version.sh"
# shellcheck source=lib/aws.sh
source "$SCRIPT_DIR/lib/aws.sh"
# shellcheck source=lib/k8s.sh
source "$SCRIPT_DIR/lib/k8s.sh"
# shellcheck source=lib/role_discovery.sh
source "$SCRIPT_DIR/lib/role_discovery.sh"
# shellcheck source=lib/policy_validation.sh
source "$SCRIPT_DIR/lib/policy_validation.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────

usage() {
  awk '/^#!/{next} /^#/{sub(/^# ?/,""); print; next} /^[[:space:]]*$/{next} {exit}' "$0"
  exit 0
}

die() { echo "❌ $*" >&2; exit 1; }

verify_dependencies() {
  local missing=()
  for tool in aws kubectl jq diff; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "Missing required tools: ${missing[*]}"
}

# step <number> <description>
# Prints a section header for a numbered validation step.
step() {
  local num="$1"
  local desc="$2"
  echo ""
  echo "  Step $num  ·  $desc"
  echo "  $(printf '─%.0s' $(seq 1 $(( ${#desc} + 10 ))))"
}

# pass <message>
pass() { echo "  ✅  $*"; }

# fail <message>  — prints the failure and exits 1
fail() { echo "  ❌  $*" >&2; exit 1; }

# ── Expected policy document ──────────────────────────────────────────────────
# Canonical source: upstream iam_policy.json + Gateway API amendment.
# Duplicated here so validate_auth.sh is independently runnable without also
# running validate_iam_policy.sh.

read -r -d '' EXPECTED_POLICY_JSON << 'EOF' || true
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["iam:CreateServiceLinkedRole"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeVpcPeeringConnections",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeTags",
        "ec2:GetCoipPoolUsage",
        "ec2:DescribeCoipPools",
        "ec2:GetSecurityGroupsForVpc",
        "ec2:DescribeIpamPools",
        "ec2:DescribeRouteTables",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:DescribeTrustStores",
        "elasticloadbalancing:DescribeListenerAttributes",
        "elasticloadbalancing:DescribeCapacityReservation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateSecurityGroup"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateTags"],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "StringEquals": { "ec2:CreateAction": "CreateSecurityGroup" },
        "Null": { "aws:RequestTag/elbv2.k8s.aws/cluster": "false" }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateTags", "ec2:DeleteTags"],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": { "aws:ResourceTag/elbv2.k8s.aws/cluster": "false" }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": { "aws:RequestTag/elbv2.k8s.aws/cluster": "false" }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags"
      ],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      ],
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags"
      ],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:ModifyListenerAttributes",
        "elasticloadbalancing:ModifyCapacityReservation",
        "elasticloadbalancing:ModifyIpPools"
      ],
      "Resource": "*",
      "Condition": {
        "Null": { "aws:ResourceTag/elbv2.k8s.aws/cluster": "false" }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:AddTags"],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      ],
      "Condition": {
        "StringEquals": {
          "elasticloadbalancing:CreateAction": [
            "CreateTargetGroup",
            "CreateLoadBalancer"
          ]
        },
        "Null": { "aws:RequestTag/elbv2.k8s.aws/cluster": "false" }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule",
        "elasticloadbalancing:SetRulePriorities"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DescribeListenerAttributes",
        "elasticloadbalancing:ModifyListenerAttributes"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# ── Auth chain validation ─────────────────────────────────────────────────────

validate_auth() {
  local sa_name="$1"
  local namespace="$2"
  local cluster_name="$3"
  local region="$4"
  local expected_policy_name="$5"   # empty -> discover instead of matching a name

  echo "══════════════════════════════════════════════════════════"
  echo "  IAM Auth Chain Validation"
  echo "══════════════════════════════════════════════════════════"

  # ── Step 1: ServiceAccount exists ──────────────────────────────────────────
  step 1 "ServiceAccount exists"
  echo "  Namespace : $namespace"
  echo "  Name      : $sa_name"

  if service_account_exists "$sa_name" "$namespace"; then
    pass "ServiceAccount '$sa_name' found in namespace '$namespace'."
  else
    fail "ServiceAccount '$sa_name' not found in namespace '$namespace'."
  fi

  # ── Step 2: bound to an IAM role via IRSA or Pod Identity ───────────────────
  step 2 "Bound to an IAM role (IRSA or Pod Identity)"

  local role_arn auth_mode=""
  role_arn=$(get_service_account_annotation "$sa_name" "$namespace" 'eks\.amazonaws\.com/role-arn')

  if [[ -n "$role_arn" ]]; then
    auth_mode="IRSA"
    pass "IRSA role-arn annotation present."
  elif [[ -n "$cluster_name" && -n "$region" ]]; then
    role_arn=$(get_pod_identity_role_arn "$cluster_name" "$namespace" "$sa_name" "$region")
    if [[ -n "$role_arn" ]]; then
      auth_mode="Pod Identity"
      pass "Pod Identity association found."
    fi
  fi

  if [[ -z "$role_arn" ]]; then
    if [[ -z "$cluster_name" || -z "$region" ]]; then
      fail "No IRSA role-arn annotation on '$sa_name', and --cluster-name/--region (or \$EKS_CLUSTER_NAME/\$EKS_REGION) weren't given, so a Pod Identity association couldn't be looked up either."
    else
      fail "ServiceAccount '$sa_name' is bound to a role via neither an IRSA role-arn annotation nor an EKS Pod Identity association in region '$region'."
    fi
  fi

  echo "  Auth mode : $auth_mode"
  echo "  Role ARN  : $role_arn"

  local role_name="${role_arn##*/}"
  echo "  Role Name : $role_name"

  # ── Step 3: IAM role exists ─────────────────────────────────────────────────
  step 3 "IAM role exists"

  if role_exists "$role_name"; then
    pass "IAM role '$role_name' exists."
  else
    fail "IAM role '$role_name' does not exist (or is not accessible)."
  fi

  # ── Step 4: policy is attached to the role ──────────────────────────────────
  step 4 "Policy attached to role"

  local matched_policy_arn=""

  if [[ -n "$expected_policy_name" ]]; then
    echo "  Looking for : $expected_policy_name"

    local -a attached_arns=()
    get_role_attached_policy_arns "$role_name" attached_arns

    for arn in "${attached_arns[@]}"; do
      local attached_name="${arn##*/}"
      if [[ "$attached_name" == "$expected_policy_name" ]]; then
        matched_policy_arn="$arn"
        break
      fi
    done

    if [[ -z "$matched_policy_arn" ]]; then
      echo "  Attached policies on role '$role_name':"
      if [[ ${#attached_arns[@]} -eq 0 ]]; then
        echo "    (none)"
      else
        for arn in "${attached_arns[@]}"; do
          echo "    • $arn"
        done
      fi
      fail "Policy '$expected_policy_name' is not attached to role '$role_name'."
    fi
  else
    echo "  No --policy-name given -- discovering whichever policy is attached..."
    matched_policy_arn=$(find_attached_policy_arn "$role_name")
  fi

  pass "Policy is attached."
  echo "  Policy ARN  : $matched_policy_arn"

  # ── Step 5: policy document is correct ──────────────────────────────────────
  step 5 "Policy document contents"
  echo ""
  echo "──────────────────────────────────────────────────────────"
  echo "  IAM Policy Validation"
  echo "  $matched_policy_arn"
  echo "──────────────────────────────────────────────────────────"

  validate_policy "$matched_policy_arn"

  # ── Final summary ────────────────────────────────────────────────────────────
  echo ""
  echo "══════════════════════════════════════════════════════════"
  echo "  ✅  All auth chain checks passed ($auth_mode)."
  echo "══════════════════════════════════════════════════════════"
}

# ── Argument parsing ──────────────────────────────────────────────────────────

main() {
  local sa_name="aws-load-balancer-controller"
  local namespace="kube-system"
  local cluster_name="${EKS_CLUSTER_NAME:-}"
  local region="${EKS_REGION:-}"
  local policy_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--service-account)
        sa_name="${2:?--service-account requires a value}"
        shift 2
        ;;
      -n|--namespace)
        namespace="${2:?--namespace requires a value}"
        shift 2
        ;;
      -c|--cluster-name)
        cluster_name="${2:?--cluster-name requires a value}"
        shift 2
        ;;
      -r|--region)
        region="${2:?--region requires a value}"
        shift 2
        ;;
      -p|--policy-name)
        policy_name="${2:?--policy-name requires a value}"
        shift 2
        ;;
      -h|--help) usage ;;
      *) die "Unknown argument '$1'. Pass --help for usage." ;;
    esac
  done

  verify_bash
  verify_dependencies
  verify_aws_connectivity
  verify_kubectl

  validate_auth "$sa_name" "$namespace" "$cluster_name" "$region" "$policy_name"
}

main "$@"
