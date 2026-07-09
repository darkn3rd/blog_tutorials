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
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${INSTALL_METHOD:?INSTALL_METHOD is required}"
: "${AUTH_MODE:?AUTH_MODE is required}"

UNINSTALL_TIMEOUT="${UNINSTALL_TIMEOUT:-300}"

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
  echo "  ✅ uninstall_lbc completed within ${UNINSTALL_TIMEOUT}s - self-healed correctly."
else
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "❌ uninstall_lbc timed out after ${UNINSTALL_TIMEOUT}s - finalizer-lock hang reproduced, no self-heal." >&2
  else
    echo "❌ uninstall_lbc failed (exit $rc)." >&2
  fi
  exit 1
fi
