#!/usr/bin/env bash
# validate_iam_policy.sh — Verify the AWS Load Balancer Controller IAM policy
#                          contains every required statement.
#
# Usage:
#   validate_iam_policy.sh [options]
#
# Options:
#   -p, --policy-name  IAM policy name to validate  (default: AWSLoadBalancerControllerIAMPolicy)
#   -a, --account-id   AWS account ID  (default: resolved via sts get-caller-identity)
#   -h, --help         Show this help message.
#
# Exit codes:
#   0  Policy is present and every required statement is satisfied.
#   1  Policy is missing, inaccessible, or one or more statements fail validation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────

DEFAULT_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

# ── Expected policy document ──────────────────────────────────────────────────
# Canonical source: iam_policy.json from the upstream LBC repo, plus the
# Gateway API amendment that adds DescribeListenerAttributes / ModifyListenerAttributes.
# Stored as a here-doc so the script is fully self-contained.

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

verify_aws_connectivity() {
  local err
  if ! err=$(aws sts get-caller-identity --query "Arn" --output text 2>&1 >/dev/null); then
    die "AWS authentication failed: $err"
  fi
}

# ── Statement fingerprinting ──────────────────────────────────────────────────
#
# A "fingerprint" is a normalised, order-independent JSON string that uniquely
# represents a statement for comparison purposes:
#
#   - Effect     : kept as-is
#   - Action     : sorted array (so order doesn't matter)
#   - Resource   : sorted array (strings coerced to single-element array first)
#   - Condition  : sorted keys at every level via walk/to_entries/sort/from_entries
#
# Statements with no Condition get a null sentinel so the fingerprint always
# has the same four keys and two statements that differ only in Condition are
# never considered equal.

# fingerprint_statement <json-statement> → normalised JSON string
fingerprint_statement() {
  local stmt="$1"
  echo "$stmt" | jq -c '
    def sort_condition:
      if . == null then null
      else to_entries
        | map(.value |= if type == "object"
            then to_entries | sort_by(.key) | from_entries
            else . end)
        | sort_by(.key)
        | from_entries
      end;

    {
      Effect: .Effect,
      Action: (
        if (.Action | type) == "string" then [.Action] else .Action end
        | sort
      ),
      Resource: (
        if (.Resource | type) == "string" then [.Resource] else .Resource end
        | sort
      ),
      Condition: (.Condition // null | sort_condition)
    }
  '
}

# build_fingerprint_map <policy-json> <nameref>
# Populates nameref associative array: fingerprint → original statement JSON
build_fingerprint_map() {
  local policy="$1"
  local -n _map="${2:?nameref required}"
  _map=()

  local count
  count=$(echo "$policy" | jq '.Statement | length')

  for (( i=0; i<count; i++ )); do
    local stmt fp
    stmt=$(echo "$policy" | jq ".Statement[$i]")
    fp=$(fingerprint_statement "$stmt")
    _map["$fp"]="$stmt"
  done
}

# ── AWS policy fetch ──────────────────────────────────────────────────────────

fetch_live_policy() {
  local policy_arn="$1"

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
    || die "Could not retrieve policy version $version_id for $policy_arn"
}

# ── Diff formatting ───────────────────────────────────────────────────────────

# pretty_diff <expected_stmt_json> <actual_stmt_json|"">
# Prints a coloured unified diff (or a note when nothing matched at all).
pretty_diff() {
  local expected="$1"
  local actual="${2:-}"

  local exp_pretty act_pretty
  exp_pretty=$(echo "$expected" | jq '.')

  if [[ -z "$actual" ]]; then
    # No statement in the live policy matched at all — show expected only
    echo "    Expected statement (no match found in live policy):"
    echo "$exp_pretty" | sed 's/^/    /'
    return
  fi

  act_pretty=$(echo "$actual" | jq '.')
  diff --unified=3 \
    <(echo "$exp_pretty") \
    <(echo "$act_pretty") \
    | tail -n +4 \
    | sed 's/^-/    − /; s/^+/    + /; s/^ /      /' \
    || true   # diff exits 1 when files differ; that's expected here
}

# ── Core validation ───────────────────────────────────────────────────────────

validate_policy() {
  local policy_arn="$1"

  echo "Fetching live policy..."
  local live_policy
  live_policy=$(fetch_live_policy "$policy_arn")

  # Build fingerprint maps for both sides
  local -A live_fps=()
  build_fingerprint_map "$live_policy" live_fps

  local expected_count
  expected_count=$(echo "$EXPECTED_POLICY_JSON" | jq '.Statement | length')

  local -a failed_indices=()
  local -A failed_expected=()    # index → expected stmt JSON
  local -A failed_actual=()      # index → closest actual stmt JSON (may be empty)

  echo ""
  echo "──────────────────────────────────────────────────────────"
  echo "  IAM Policy Validation  ·  $policy_arn"
  echo "──────────────────────────────────────────────────────────"
  echo ""
  echo "  Required Statements  ($expected_count total)"
  echo "  ──────────────────────────────────────────"

  for (( i=0; i<expected_count; i++ )); do
    local exp_stmt exp_fp label

    exp_stmt=$(echo "$EXPECTED_POLICY_JSON" | jq ".Statement[$i]")
    exp_fp=$(fingerprint_statement "$exp_stmt")

    # Build a short human-readable label from the first action + resource type
    local first_action resource_label
    first_action=$(echo "$exp_stmt" | jq -r '
      if (.Action | type) == "string" then .Action
      else .Action[0] end')
    resource_label=$(echo "$exp_stmt" | jq -r '
      if (.Resource | type) == "string" then .Resource
      elif (.Resource | length) == 1 then .Resource[0]
      else "[\(.Resource | length) resources]" end' \
      | sed 's|arn:aws:[^:]*:[^:]*:[^:]*:||')

    local action_count
    action_count=$(echo "$exp_stmt" | jq '
      if (.Action | type) == "string" then 1 else .Action | length end')

    if [[ $action_count -gt 1 ]]; then
      label="${first_action}  (+$(( action_count - 1 )) more)  →  ${resource_label}"
    else
      label="${first_action}  →  ${resource_label}"
    fi

    if [[ -n "${live_fps[$exp_fp]+_}" ]]; then
      echo "  ✅  $label"
    else
      echo "  ❌  $label"
      failed_indices+=("$i")
      failed_expected["$i"]="$exp_stmt"

      # Try to find the closest actual statement by matching on the first action
      local closest=""
      local live_fp
      for live_fp in "${!live_fps[@]}"; do
        local live_first
        live_first=$(echo "${live_fps[$live_fp]}" | jq -r '
          if (.Action | type) == "string" then .Action
          else .Action[0] end')
        if [[ "$live_first" == "$first_action" ]]; then
          closest="${live_fps[$live_fp]}"
          break
        fi
      done
      failed_actual["$i"]="$closest"
    fi
  done

  echo ""
  echo "──────────────────────────────────────────────────────────"

  local pass_count=$(( expected_count - ${#failed_indices[@]} ))

  if [[ ${#failed_indices[@]} -eq 0 ]]; then
    echo "  ✅  All $expected_count required statements are present."
    echo "──────────────────────────────────────────────────────────"
    return 0
  fi

  echo "  ❌  $pass_count of $expected_count statements matched  (${#failed_indices[@]} failed)."
  echo "──────────────────────────────────────────────────────────"

  # ── Per-statement diffs ───────────────────────────────────────────────────

  echo ""
  echo "  Failed Statement Diffs"
  echo "  ─────────────────────────────────────────────────────────"

  for i in "${failed_indices[@]}"; do
    local exp_stmt="${failed_expected[$i]}"
    local act_stmt="${failed_actual[$i]:-}"

    local first_action
    first_action=$(echo "$exp_stmt" | jq -r '
      if (.Action | type) == "string" then .Action else .Action[0] end')

    echo ""
    echo "  Statement $((i+1))  ·  ${first_action}  ..."
    echo "  Legend:  − expected   + live policy"
    echo ""
    pretty_diff "$exp_stmt" "$act_stmt"
    echo ""
    echo "  ·····················································"
  done

  return 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

main() {
  local policy_name="$DEFAULT_POLICY_NAME"
  local account_id=""

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
      -h|--help) usage ;;
      *) die "Unknown argument '$1'. Pass --help for usage." ;;
    esac
  done

  verify_dependencies
  verify_aws_connectivity

  if [[ -z "$account_id" ]]; then
    echo "Resolving AWS account ID..."
    account_id=$(aws sts get-caller-identity --query "Account" --output text)
  fi

  local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

  validate_policy "$policy_arn"
}

main "$@"
