#!/usr/bin/env bash
# suites/negative_finalizer_lock.sh — regression test for the finalizer-lock
# hang this session hit repeatedly: uninstalling the Helm release (killing
# the controller) before deprovisioning live Gateway API objects strands
# them with a live finalizer and nothing left to clear it, hanging any
# subsequent CRD deletion forever.
#
# By this phase (06), the normal demos from phase 04 are already up -
# reuses demo-gwtcp/demo-gwhttp rather than deploying anything new.
# Deliberately reproduces the bug by removing the Helm release directly
# (bypassing the safe deprovision-first order every install_method's real
# uninstall path uses), then runs this case's normal uninstall_lbc under a
# hard `timeout` and asserts it actually completes.
#
# NOTE on install_method=terraform: uninstall_aws_lbc.sh got a self-healing
# fix this session (force_clear_stuck_finalizers, invoked after a bounded
# poll) specifically for this scenario. Terraform's destroy path
# (lbc_install -> lbc_setup -> lbc_prep, reverse-applied - Helm before CRDs,
# same ordering that caused the original bug) has no equivalent fix. A
# terraform-case failure here is a legitimate, expected finding pointing at
# that gap, not a suite defect - the `timeout` wrapper exists precisely so
# that finding surfaces as a bounded, reported failure instead of hanging
# the whole matrix run.
#
# NOTE on verification: this suite used to treat uninstall_lbc's exit code
# as the whole answer. That was a real false positive once already -
# uninstall_aws_lbc.sh printed "Cleanup completed successfully!" while 4
# TargetGroupBinding objects (elbv2.k8s.aws - a resource kind its detection
# logic didn't know about yet) sat stuck with live finalizers, blocking
# their namespaces from ever finishing deletion. Fixed in both
# uninstall_aws_lbc.sh and lib/contract.sh's verify_clean(), but the lesson
# generalizes: this suite now independently calls verify_clean() afterward
# rather than trusting the exit code alone, so a similarly-missed resource
# kind in the future fails this suite instead of silently passing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${INSTALL_METHOD:?INSTALL_METHOD is required}"
: "${AUTH_MODE:?AUTH_MODE is required}"

# 480s, not 300s: a full self-heal now includes real aws elbv2
# delete-load-balancer/delete-target-group calls (force_clear_stuck_finalizers
# force-deletes orphaned AWS load balancers, not just Kubernetes finalizers -
# see uninstall_aws_lbc.sh), which are asynchronous and take real time to
# converge, on top of the normal CRD/Helm/IAM teardown that follows.
UNINSTALL_TIMEOUT="${UNINSTALL_TIMEOUT:-480}"

echo "  Confirming a Gateway API demo is live to strand..."
if ! kubectl get gateway --all-namespaces -o name 2>/dev/null | grep -q .; then
  die "No live Gateway found - was phase 04 (deploy_demos) run before this suite?"
fi

echo "  Force-removing the Helm release directly, bypassing the safe deprovision-first order..."
helm uninstall aws-load-balancer-controller --namespace kube-system 2>&1 || true

echo "  Confirming at least one Gateway/GatewayClass is now stranded (deletion not yet requested, controller gone)..."
kubectl get gateway,gatewayclass --all-namespaces 2>&1 || true

echo "  Running uninstall_lbc under a ${UNINSTALL_TIMEOUT}s timeout, expecting it to self-heal and complete..."
if timeout "$UNINSTALL_TIMEOUT" bash -c "
  source '$TESTS_DIR/lib/contract.sh'
  uninstall_lbc '$INSTALL_METHOD' '$AUTH_MODE'
"; then
  echo "  uninstall_lbc returned success within ${UNINSTALL_TIMEOUT}s - independently verifying state (not just trusting the exit code: that's exactly how the missing-TargetGroupBinding gap slipped through once already)..."
else
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "❌ uninstall_lbc timed out after ${UNINSTALL_TIMEOUT}s - finalizer-lock hang reproduced, no self-heal." >&2
  else
    echo "❌ uninstall_lbc failed (exit $rc)." >&2
  fi
  exit 1
fi

# --skip-namespaces: cleanup_demos (phase 07) hasn't run yet at this point
# in the flow (this suite runs at phase 06), so the demo namespaces
# themselves are still expected to exist - only LBC-side state matters here.
if verify_clean "$INSTALL_METHOD" --skip-namespaces; then
  echo "  ✅ Independently verified clean - self-healed correctly."
else
  echo "❌ uninstall_lbc reported success but verify_clean found leftover resources - a false positive." >&2
  exit 1
fi
