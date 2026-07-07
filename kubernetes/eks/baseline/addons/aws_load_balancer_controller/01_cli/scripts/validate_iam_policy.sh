#!/usr/bin/env bash
# validate_iam_policy.sh — Verify the AWS Load Balancer Controller IAM policy
#                          contains every required statement.
#
# Usage:
#   validate_iam_policy.sh [options]
#
# Options:
#   -p, --policy-name      IAM policy name to validate. If omitted, the
#                          policy is discovered instead: found via whichever
#                          role is bound to the controller's ServiceAccount
#                          (IRSA annotation or Pod Identity association), then
#                          whichever single policy is attached to that role --
#                          regardless of what either is named.
#   -a, --account-id       AWS account ID  (default: resolved via sts get-caller-identity)
#   -c, --cluster-name     EKS cluster name, needed for discovery's Pod
#                          Identity lookup  (default: $EKS_CLUSTER_NAME)
#   -r, --region           AWS region the cluster lives in, needed for
#                          discovery's Pod Identity lookup -- it's a
#                          region-scoped API call, so the wrong region (or
#                          none) silently finds nothing instead of erroring
#                          (default: $EKS_REGION)
#   -n, --namespace        ServiceAccount's namespace, for discovery
#                          (default: kube-system)
#   -s, --service-account  ServiceAccount name, for discovery
#                          (default: aws-load-balancer-controller)
#   -h, --help             Show this help message.
#
# Exit codes:
#   0  Policy is present and all required statements are satisfied.
#   1  Policy is missing, inaccessible, or one or more statements fail.
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
  for tool in aws jq diff; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "Missing required tools: ${missing[*]}"
}

# ── Expected policy document ──────────────────────────────────────────────────
# Canonical source: upstream iam_policy.json + Gateway API amendment
# (DescribeListenerAttributes / ModifyListenerAttributes).

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

# ── Argument parsing ──────────────────────────────────────────────────────────

main() {
  local policy_name=""
  local account_id=""
  local cluster_name="${EKS_CLUSTER_NAME:-}"
  local region="${EKS_REGION:-}"
  local namespace="kube-system"
  local sa_name="aws-load-balancer-controller"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--policy-name)
        policy_name="${2:?--policy-name requires a value}"
        shift 2
        ;;
      -a|--account-id)
        account_id="${2:?--account-id requires a value}"
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
      -n|--namespace)
        namespace="${2:?--namespace requires a value}"
        shift 2
        ;;
      -s|--service-account)
        sa_name="${2:?--service-account requires a value}"
        shift 2
        ;;
      -h|--help) usage ;;
      *) die "Unknown argument '$1'. Pass --help for usage." ;;
    esac
  done

  verify_bash
  verify_dependencies
  verify_aws_connectivity

  if [[ -z "$account_id" ]]; then
    echo "Resolving AWS account ID..."
    account_id=$(get_account_id)
  fi

  local policy_arn

  if [[ -n "$policy_name" ]]; then
    policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"
  else
    [[ -n "$cluster_name" ]] \
      || die "No --policy-name given, so the role/policy must be discovered -- pass --cluster-name (or set \$EKS_CLUSTER_NAME) so a Pod Identity association can be looked up if there's no IRSA annotation."
    [[ -n "$region" ]] \
      || die "No --policy-name given, so the role/policy must be discovered -- pass --region (or set \$EKS_REGION), since the Pod Identity lookup is region-scoped."

    verify_kubectl

    echo "No --policy-name given -- discovering the role and policy from the '$sa_name' ServiceAccount..."
    local role_arn role_name
    role_arn=$(find_role_arn "$cluster_name" "$namespace" "$sa_name" "$region")
    role_name="${role_arn##*/}"
    echo "  Role   : $role_name"

    policy_arn=$(find_attached_policy_arn "$role_name")
    echo "  Policy : ${policy_arn##*/}"
  fi

  echo ""
  echo "──────────────────────────────────────────────────────────"
  echo "  IAM Policy Validation"
  echo "  $policy_arn"
  echo "──────────────────────────────────────────────────────────"
  validate_policy "$policy_arn"
}

main "$@"
