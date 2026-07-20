#!/usr/bin/env bash
# suites/negative_name_collision.sh — regression test for the IAM
# name-collision escalation described in 03_python/*/lib/naming.py: an ops
# engineer installing this against two EKS clusters (e.g. test and stage)
# gets the same cluster-scoped policy/role name computed for both if they
# happen to collide (hand-created resource, leftover from a torn-down
# environment that reused the cluster name, etc.) - the installer must
# detect that and pick another name instead of failing or silently
# clobbering someone else's resource.
#
# Only python-* install methods have this logic (the bash cli-eksctl/
# cli-aws/terraform paths use eksctl/CloudFormation-generated unique names
# or are covered by the existing stale-policy-content collision test in
# negative_collision.sh). Skips as a no-op for every other install_method.
#
# Uses a synthetic cluster name, not $EKS_CLUSTER_NAME: IAM names are
# account-global, so no real EKS cluster is needed to exercise this, and
# the real cluster's attempt-0 policy/role already exists and is
# legitimately tagged as owned by it by this point in the run (phase 06,
# after install) - reusing that name here would only prove idempotent
# reuse (already covered by unit tests), not collision escalation.
#
# This calls the installer's own resolve_policy_name()/resolve_role_name()
# (and, for uninstall, find_owned_policy_arn()) directly against real AWS
# IAM - not a bash re-implementation of the hashing algorithm - so this
# test can't silently drift from the production code path it's checking.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"
: "${INSTALL_METHOD:?INSTALL_METHOD is required}"

case "$INSTALL_METHOD" in
  python-direct-api|python-exec-cli-eksctl|python-exec-cli-awscli) ;;
  *)
    echo "  Skipping: name-collision escalation only applies to python-* install methods (got '$INSTALL_METHOD')."
    exit 0
    ;;
esac

SYNTH_CLUSTER="lbc-collision-test-$(date +%s)-$$"
account_id="$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)"

case "$INSTALL_METHOD" in
  python-direct-api)
    PY_DIR="$PROJECT_DIR/03_python/direct_api"
    ensure_python_venv "$PY_DIR"
    PY="$PY_DIR/.venv/bin/python"
    ;;
  python-exec-cli-eksctl|python-exec-cli-awscli)
    # No third-party deps - runs on the system python3, same as
    # install_lbc_python_exec_cli() in lib/contract.sh.
    PY_DIR="$PROJECT_DIR/03_python/exec_cli"
    PY="python3"
    ;;
esac

attempt0_policy_name=""
attempt0_role_name=""
rc=0

cleanup() {
  if [[ -n "$attempt0_policy_name" ]]; then
    aws iam delete-policy --profile "$AWS_PROFILE" \
      --policy-arn "arn:aws:iam::${account_id}:policy/${attempt0_policy_name}" >/dev/null 2>&1 || true
  fi
  if [[ -n "$attempt0_role_name" ]]; then
    aws iam delete-role --profile "$AWS_PROFILE" --role-name "$attempt0_role_name" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# ── Policy escalation ────────────────────────────────────────────────────
# Applies to every python-* method - the policy is always created/looked up
# directly by this installer regardless of tool_mode (see
# 03_python/*/lib/naming.py's module docstring).

attempt0_policy_name="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
from lib import naming
print(naming.policy_name('$SYNTH_CLUSTER'))
")"
echo "  Pre-creating a bogus, untagged policy at the synthetic cluster's attempt-0 name: $attempt0_policy_name"
aws iam create-policy --profile "$AWS_PROFILE" --policy-name "$attempt0_policy_name" \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"sts:GetCallerIdentity","Resource":"*"}]}' \
  >/dev/null

echo "  Calling resolve_policy_name() for the synthetic cluster, expecting it to escalate past the collision..."
case "$INSTALL_METHOD" in
  python-direct-api)
    escalated_policy_name="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
from lib import aws as awslib
clients = awslib.AwsClients.create(profile='$AWS_PROFILE', region='$EKS_REGION')
print(awslib.resolve_policy_name(clients, '$account_id', '$SYNTH_CLUSTER'))
")"
    ;;
  python-exec-cli-eksctl|python-exec-cli-awscli)
    escalated_policy_name="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
import install_aws_lbc as inst
print(inst.resolve_policy_name('$account_id', '$SYNTH_CLUSTER', '$AWS_PROFILE'))
")"
    ;;
esac

if [[ -z "$escalated_policy_name" ]]; then
  echo "❌ resolve_policy_name produced no output - it likely died. Check the traceback above." >&2
  rc=1
elif [[ "$escalated_policy_name" == "$attempt0_policy_name" ]]; then
  echo "❌ resolve_policy_name reused the colliding attempt-0 name instead of escalating - regression." >&2
  rc=1
else
  echo "  ✅ Escalated to a new, untaken name: $escalated_policy_name"
fi

# ── Role escalation ──────────────────────────────────────────────────────
# Only where this installer creates the IAM role directly: direct-api
# always, exec-cli only in its aws-cli tool mode. eksctl generates its own
# uniquely-named role via CloudFormation, so exec-cli-eksctl has nothing to
# escalate for the role.
test_role=0
case "$INSTALL_METHOD" in
  python-direct-api|python-exec-cli-awscli) test_role=1 ;;
esac

if [[ "$test_role" -eq 1 ]]; then
  attempt0_role_name="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
from lib import naming
print(naming.role_name('$SYNTH_CLUSTER'))
")"
  echo "  Pre-creating a bogus, untagged role at the synthetic cluster's attempt-0 name: $attempt0_role_name"
  aws iam create-role --profile "$AWS_PROFILE" --role-name "$attempt0_role_name" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    >/dev/null

  echo "  Calling resolve_role_name() for the synthetic cluster, expecting it to escalate past the collision..."
  case "$INSTALL_METHOD" in
    python-direct-api)
      escalated_role_name="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
from lib import aws as awslib
clients = awslib.AwsClients.create(profile='$AWS_PROFILE', region='$EKS_REGION')
print(awslib.resolve_role_name(clients, '$SYNTH_CLUSTER'))
")"
      ;;
    python-exec-cli-awscli)
      escalated_role_name="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
import install_aws_lbc as inst
print(inst.resolve_role_name('$SYNTH_CLUSTER', '$AWS_PROFILE'))
")"
      ;;
  esac

  if [[ -z "$escalated_role_name" ]]; then
    echo "❌ resolve_role_name produced no output - it likely died. Check the traceback above." >&2
    rc=1
  elif [[ "$escalated_role_name" == "$attempt0_role_name" ]]; then
    echo "❌ resolve_role_name reused the colliding attempt-0 name instead of escalating - regression." >&2
    rc=1
  else
    echo "  ✅ Escalated to a new, untaken name: $escalated_role_name"
  fi
fi

# ── Uninstall-side discovery ─────────────────────────────────────────────
# Proves the other half of the feature: if install had escalated (as just
# shown above), uninstall must still be able to find what it created by
# ownership tag, not by blindly recomputing the attempt-0 name. Simulates
# that by tagging the bogus attempt-0 policy itself as owned by a second
# synthetic cluster, then confirming find_owned_policy_arn() discovers it
# there (attempt-0, this time legitimately "ours") - and separately, that
# it returns nothing for a cluster name that owns nothing at all.

echo "  Verifying uninstall-side discovery (find_owned_policy_arn) against a fresh synthetic cluster with nothing owned..."
SYNTH_CLUSTER_EMPTY="lbc-collision-test-empty-$(date +%s)-$$"
case "$INSTALL_METHOD" in
  python-direct-api)
    discovered_empty="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
from lib import aws as awslib
clients = awslib.AwsClients.create(profile='$AWS_PROFILE', region='$EKS_REGION')
result = awslib.find_owned_policy_arn(clients, '$account_id', '$SYNTH_CLUSTER_EMPTY')
print(result if result else '')
")"
    ;;
  python-exec-cli-eksctl|python-exec-cli-awscli)
    discovered_empty="$(cd "$PY_DIR" && "$PY" -c "
import sys; sys.path.insert(0, '.')
import uninstall_aws_lbc as uninst
result = uninst.find_owned_policy_arn('$account_id', '$SYNTH_CLUSTER_EMPTY', '$AWS_PROFILE')
print(result if result else '')
")"
    ;;
esac

if [[ -n "$discovered_empty" ]]; then
  echo "❌ find_owned_policy_arn found something ($discovered_empty) for a cluster that owns nothing - false positive." >&2
  rc=1
else
  echo "  ✅ Correctly found nothing for a cluster with no owned policy."
fi

exit $rc
