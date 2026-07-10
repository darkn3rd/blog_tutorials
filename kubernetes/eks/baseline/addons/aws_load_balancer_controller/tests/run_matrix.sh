#!/usr/bin/env bash
# run_matrix.sh — orchestrates the install-method x auth-mode test matrix
# defined in matrix.yaml.
#
# Usage:
#   ./run_matrix.sh --case <name> [--suites <suite,suite,...>]
#   ./run_matrix.sh --all [--suites <suite,...>] [--keep-cluster]
#   ./run_matrix.sh --tier <name> [--keep-cluster]
#   ./run_matrix.sh --destroy-cluster
#
# --suites overrides which suites run (default: positive only) for --case/
# --all - e.g. --case cli-eksctl-podid --suites negative-collision,negative-finalizer-lock
# to target one case with specific negative suites without paying for the
# other cases a --tier would also run. Not valid with --tier, which already
# defines its own suites in matrix.yaml.
#
# Cluster lifecycle differs by mode, matching two different usage patterns:
#
#   --case <name>   Ad-hoc/discrete testing - provisions a cluster ONLY if
#                    none is currently up and reachable (tests/logs/cluster.env
#                    plus a live kubectl cluster-info check), and NEVER
#                    destroys it afterward. Run --case repeatedly against the
#                    same cluster without paying the ~15-20min provision cost
#                    every time; run --destroy-cluster explicitly when done.
#
#   --all / --tier   Batch runs - always provisions a fresh cluster first and
#                    destroys it after every case finishes (matching "kick it
#                    off and check back later/overnight"), unless
#                    --keep-cluster is passed to skip both and reuse
#                    whatever's already up.
#
#   --destroy-cluster  Tears down whatever tests/logs/cluster.env currently
#                    points at. The explicit "I'm done" command for the
#                    --case workflow above.
#
# Required env: CLUSTER_PROVISIONER_ROOT, EKS_REGION, AWS_PROFILE, KUBECONFIG.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"
LOGS_DIR="$TESTS_DIR/logs"

die() { echo "❌ $*" >&2; exit 1; }
# shellcheck source=../scripts/lib/bash_version.sh
source "$SCRIPT_DIR/../scripts/lib/bash_version.sh"
verify_bash

usage() {
  awk '/^#!/{next} /^#/{sub(/^# ?/,""); print; next} /^[[:space:]]*$/{next} {exit}' "$0"
  exit 0
}

# Handled before required-variable checks below so --help works even
# without AWS_PROFILE/CLUSTER_PROVISIONER_ROOT set.
for arg in "$@"; do
  case "$arg" in
    -h | --help) usage ;;
  esac
done

# fd 3 preserves the real terminal, saved before this script's own stdout is
# wrapped below. phases/00_provision_cluster.sh and 09_destroy_cluster.sh
# already timestamp their own output internally (they call terraform
# directly and need that whether run standalone or through here) - piping
# their output back through THIS script's own wrapper would double-stamp
# every line, so their pass-through calls write to &3 instead of inheriting
# this script's (by-then-wrapped) stdout.
exec 3>&1

# Every line of this script's OWN top-level output gets a UTC timestamp
# prefix from here on (after --help). Cases can run for many minutes end to
# end; this is separate from (and doesn't interfere with) each phase's own
# log file, which run_logged_phase() writes to directly via its own
# redirection - and separate from the per-line timestamps the leaf scripts
# (install_aws_lbc.sh etc.) already add to their own output before it lands
# in those log files.
# Dedups repeated tool-progress lines (terraform "Still creating...
# [Ns elapsed]" heartbeats, eksctl repeated "waiting for..." lines) so a
# slow apply doesn't spam the terminal, while any genuinely new/changed
# line (a different resource, a different message) always prints
# immediately. Lines from this script itself (==>/status markers) print
# as-is; everything else is indented to show it's from the underlying
# tool, not this script.
_tool_output_filter() {
  local _lf_last="" _lf_last_ts=0
  while IFS= read -r _line; do
    local _lf_now _lf_norm
    _lf_now=$(date +%s)
    _lf_norm="$(printf '%s' "$_line" | sed -E \
      -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T? ?[0-9]{2}:[0-9]{2}:[0-9]{2}Z? *//' \
      -e 's/[0-9]+m[0-9]+s elapsed/Ns elapsed/' \
      -e 's/\[[0-9]+s elapsed\]/[Ns elapsed]/')"
    if [[ "$_lf_norm" == "$_lf_last" ]] && (( _lf_now - _lf_last_ts < 30 )); then
      continue
    fi
    _lf_last="$_lf_norm"; _lf_last_ts="$_lf_now"
    case "$_line" in
      "==>"*|"✅"*|"❌"*|"⚠️"*|"─────"*|"====="*|"")
        printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
      *)
        printf '[%s]     | %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
    esac
  done
}
exec > >(_tool_output_filter) 2>&1

# shellcheck source=lib/yaml.sh
source "$TESTS_DIR/lib/yaml.sh"
# shellcheck source=lib/log.sh
source "$TESTS_DIR/lib/log.sh"

verify_yq
command -v jq >/dev/null 2>&1 || die "jq is required but not found in PATH."

: "${AWS_PROFILE:?AWS_PROFILE is required}"

MODE=""
TARGET=""
KEEP_CLUSTER="false"
SUITES_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      MODE="case"; TARGET="${2:?--case requires a value}"; shift 2 ;;
    --all)
      MODE="all"; shift ;;
    --tier)
      MODE="tier"; TARGET="${2:?--tier requires a value}"; shift 2 ;;
    --destroy-cluster)
      MODE="destroy-cluster"; shift ;;
    --keep-cluster)
      KEEP_CLUSTER="true"; shift ;;
    --suites)
      SUITES_OVERRIDE="${2:?--suites requires a value}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "Unknown argument '$1'. Pass --help for usage." ;;
  esac
done

[[ -n "$MODE" ]] || die "One of --case <name>, --all, --tier <name>, or --destroy-cluster is required. Pass --help for usage."
[[ -z "$SUITES_OVERRIDE" || "$MODE" == "case" || "$MODE" == "all" ]] \
  || die "--suites is only valid with --case or --all - --tier already defines its own suites in matrix.yaml."

if [[ "$MODE" == "destroy-cluster" ]]; then
  [[ -f "$LOGS_DIR/cluster.env" ]] || die "No $LOGS_DIR/cluster.env found - nothing to destroy."
  : "${CLUSTER_PROVISIONER_ROOT:?CLUSTER_PROVISIONER_ROOT is required}"
  # &3, not the inherited (already-wrapped) stdout - 09_destroy_cluster.sh
  # timestamps its own output already; see the fd 3 comment above.
  "$TESTS_DIR/phases/09_destroy_cluster.sh" >&3 2>&3
  exit $?
fi

# ── Resolve case list + suite list ──────────────────────────────────────────

declare -a CASES=()
declare -a SUITES=()

case "$MODE" in
  case)
    matrix_case_exists "$TARGET" || die "Case '$TARGET' not found in matrix.yaml."
    CASES=("$TARGET")
    ;;
  all)
    while IFS= read -r name; do CASES+=("$name"); done < <(matrix_all_case_names)
    ;;
  tier)
    matrix_tier_exists "$TARGET" || die "Tier '$TARGET' not found in matrix.yaml."
    while IFS= read -r name; do CASES+=("$name"); done < <(matrix_tier_cases "$TARGET")
    while IFS= read -r suite; do SUITES+=("$suite"); done < <(matrix_tier_suites "$TARGET")
    ;;
esac

[[ ${#CASES[@]} -gt 0 ]] || die "No cases resolved for this invocation."

if [[ -n "$SUITES_OVERRIDE" ]]; then
  SUITES=()
  IFS=',' read -r -a _requested_suites <<< "$SUITES_OVERRIDE"
  for s in "${_requested_suites[@]}"; do
    [[ -n "$s" ]] || continue
    if [[ "$s" != "positive" && ! -f "$TESTS_DIR/suites/${s//-/_}.sh" ]]; then
      die "Unknown suite '$s' - no tests/suites/${s//-/_}.sh."
    fi
    SUITES+=("$s")
  done
  [[ ${#SUITES[@]} -gt 0 ]] || die "--suites was given but resolved to nothing."
fi

# NEGATIVE_SUITES is the SUITES list minus the "positive" pseudo-suite
# (positive isn't a suites/*.sh file - it's the always-run baseline flow).
NEGATIVE_SUITES_LIST=""
for s in "${SUITES[@]:-}"; do
  [[ "$s" == "positive" || -z "$s" ]] && continue
  NEGATIVE_SUITES_LIST="${NEGATIVE_SUITES_LIST} ${s}"
done
NEGATIVE_SUITES_LIST="${NEGATIVE_SUITES_LIST# }"

echo "Cases:   ${CASES[*]}"
echo "Suites:  ${SUITES[*]:-positive}"
echo

# ── Cluster lifecycle ────────────────────────────────────────────────────

mkdir -p "$LOGS_DIR"

# cluster_is_reachable — true if logs/cluster.env points at a cluster that's
# actually still up (not just that the file exists: it could be stale from a
# run that failed post-provision, or the cluster could have been destroyed
# out-of-band).
cluster_is_reachable() {
  [[ -f "$LOGS_DIR/cluster.env" ]] || return 1
  local prev_cluster prev_kubeconfig
  prev_cluster="$(grep -m1 '^EKS_CLUSTER_NAME=' "$LOGS_DIR/cluster.env" | cut -d= -f2-)"
  prev_kubeconfig="$(grep -m1 '^KUBECONFIG=' "$LOGS_DIR/cluster.env" | cut -d= -f2-)"
  [[ -n "$prev_cluster" && -n "$prev_kubeconfig" && -f "$prev_kubeconfig" ]] || return 1
  KUBECONFIG="$prev_kubeconfig" kubectl cluster-info >/dev/null 2>&1
}

run_provision() {
  echo "===== Provisioning cluster ====="
  # tee to &3 (the real terminal - see fd 3 comment above), not a silent
  # capture: this is the slowest step in the whole framework (~15-20min for
  # the EKS cluster + node group), and terraform's own "Still creating...
  # [Ns elapsed]" heartbeats (confirmed emitted every ~10s regardless of
  # TTY) are worthless if nothing shows them until the phase finishes or
  # fails. PIPESTATUS[0], not $?, since $? after a pipeline is tee's exit
  # status, not the phase script's.
  "$TESTS_DIR/phases/00_provision_cluster.sh" 2>&1 | tee "$LOGS_DIR/00-provision-cluster.log" >&3
  local rc="${PIPESTATUS[0]}"
  if [[ "$rc" -ne 0 ]]; then
    die "Cluster provisioning failed (exit $rc) - see $LOGS_DIR/00-provision-cluster.log"
  fi
  echo "✅ Cluster provisioned."
}

case "$MODE" in
  case)
    if cluster_is_reachable; then
      echo "Reusing already-provisioned, reachable cluster (this mode never auto-destroys - run --destroy-cluster when done)."
    else
      echo "No reachable cluster found."
      run_provision
    fi
    ;;
  all|tier)
    if [[ "$KEEP_CLUSTER" == "false" ]]; then
      run_provision
    else
      [[ -f "$LOGS_DIR/cluster.env" ]] || die "--keep-cluster given but $LOGS_DIR/cluster.env not found. Run without --keep-cluster at least once first."
      echo "Reusing existing cluster (--keep-cluster)."
    fi
    ;;
esac

# shellcheck source=/dev/null
source "$LOGS_DIR/cluster.env"
export EKS_CLUSTER_NAME EKS_REGION KUBECONFIG

# ── Run each case ────────────────────────────────────────────────────────

declare -a CASE_RESULTS=()

for case_name in "${CASES[@]}"; do
  echo
  echo "===== Case: $case_name ====="

  install_method="$(matrix_case_field "$case_name" install_method)"
  auth_mode="$(matrix_case_field "$case_name" auth_mode)"
  [[ -n "$install_method" && -n "$auth_mode" ]] || die "Could not resolve install_method/auth_mode for case '$case_name'."

  export CASE_NAME="$case_name"
  export INSTALL_METHOD="$install_method"
  export AUTH_MODE="$auth_mode"
  export NEGATIVE_SUITES="$NEGATIVE_SUITES_LIST"

  case_dir="$LOGS_DIR/$case_name"
  mkdir -p "$case_dir"
  log_reset_case

  case_failed="false"

  if run_logged_phase "$case_dir" preflight preflight.log "$TESTS_DIR/phases/01_preflight.sh"; then
    if run_logged_phase "$case_dir" install install.log "$TESTS_DIR/phases/02_install_lbc.sh"; then
      run_logged_phase "$case_dir" validate_lbc validate-lbc.log "$TESTS_DIR/phases/03_validate_lbc.sh" || case_failed="true"
      if run_logged_phase "$case_dir" deploy_demos demos.log "$TESTS_DIR/phases/04_deploy_demos.sh"; then
        run_logged_phase "$case_dir" validate_demos validate-demos.log "$TESTS_DIR/phases/05_validate_demos.sh" || case_failed="true"
      else
        case_failed="true"
        log_skip_phase validate_demos "deploy_demos failed"
      fi
      run_logged_phase "$case_dir" negative_tests negative.log "$TESTS_DIR/phases/06_negative_tests.sh" || case_failed="true"
    else
      case_failed="true"
      log_skip_phase validate_lbc "install failed"
      log_skip_phase deploy_demos "install failed"
      log_skip_phase validate_demos "install failed"
      log_skip_phase negative_tests "install failed"
    fi

    # Best-effort cleanup/uninstall always runs, even after an earlier
    # failure, so the next case isn't handed a dirty cluster.
    run_logged_phase "$case_dir" cleanup_demos cleanup.log "$TESTS_DIR/phases/07_cleanup_demos.sh" || case_failed="true"
    run_logged_phase "$case_dir" uninstall_lbc uninstall.log "$TESTS_DIR/phases/08_uninstall_lbc.sh" || case_failed="true"
  else
    case_failed="true"
    for key in install validate_lbc deploy_demos validate_demos negative_tests cleanup_demos uninstall_lbc; do
      log_skip_phase "$key" "preflight failed"
    done
  fi

  suites_csv="$(IFS=,; echo "${SUITES[*]:-}")"
  overall="$(write_case_summary "$case_dir" "$case_name" "$install_method" "$auth_mode" "$suites_csv")"
  CASE_RESULTS+=("$case_name:$overall")

  if [[ "$overall" == "pass" ]]; then
    echo "===== Case $case_name: ✅ PASS ====="
  else
    echo "===== Case $case_name: ❌ FAIL ====="
  fi
done

# ── Cluster teardown ─────────────────────────────────────────────────────
# Never for --case (that mode's whole point is staying up across repeated
# ad-hoc runs) - only --all/--tier auto-destroy, and only without
# --keep-cluster.

if [[ "$MODE" != "case" && "$KEEP_CLUSTER" == "false" ]]; then
  echo
  echo "===== Destroying cluster ====="
  # See run_provision()'s comment - tee to &3, not a silent capture.
  "$TESTS_DIR/phases/09_destroy_cluster.sh" 2>&1 | tee "$LOGS_DIR/09-destroy-cluster.log" >&3
  if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
    echo "⚠️  Cluster destroy failed - see $LOGS_DIR/09-destroy-cluster.log. Manual cleanup may be required." >&2
  else
    echo "✅ Cluster destroyed."
  fi
elif [[ "$MODE" == "case" ]]; then
  echo
  echo "Cluster left up (--case mode never auto-destroys). Run './run_matrix.sh --destroy-cluster' when you're done testing."
fi

# ── Final summary ────────────────────────────────────────────────────────

echo
echo "===== Summary ====="
overall_rc=0
for entry in "${CASE_RESULTS[@]}"; do
  name="${entry%%:*}"
  result="${entry##*:}"
  if [[ "$result" == "pass" ]]; then
    echo "  ✅ $name"
  else
    echo "  ❌ $name"
    overall_rc=1
  fi
done

exit $overall_rc
