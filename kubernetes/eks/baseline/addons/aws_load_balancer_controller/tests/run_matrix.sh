#!/usr/bin/env bash
# run_matrix.sh — orchestrates the install-method x auth-mode test matrix
# defined in matrix.yaml.
#
# Usage:
#   ./run_matrix.sh --case <name>
#   ./run_matrix.sh --all [--keep-cluster]
#   ./run_matrix.sh --tier <name> [--keep-cluster]
#   ./run_matrix.sh --destroy-cluster
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
    -h|--help) usage ;;
    *) die "Unknown argument '$1'. Pass --help for usage." ;;
  esac
done

[[ -n "$MODE" ]] || die "One of --case <name>, --all, --tier <name>, or --destroy-cluster is required. Pass --help for usage."

if [[ "$MODE" == "destroy-cluster" ]]; then
  [[ -f "$LOGS_DIR/cluster.env" ]] || die "No $LOGS_DIR/cluster.env found - nothing to destroy."
  : "${CLUSTER_PROVISIONER_ROOT:?CLUSTER_PROVISIONER_ROOT is required}"
  "$TESTS_DIR/phases/09_destroy_cluster.sh"
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
  if ! "$TESTS_DIR/phases/00_provision_cluster.sh" > "$LOGS_DIR/00-provision-cluster.log" 2>&1; then
    cat "$LOGS_DIR/00-provision-cluster.log" >&2
    die "Cluster provisioning failed - see $LOGS_DIR/00-provision-cluster.log"
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
  if ! "$TESTS_DIR/phases/09_destroy_cluster.sh" > "$LOGS_DIR/09-destroy-cluster.log" 2>&1; then
    cat "$LOGS_DIR/09-destroy-cluster.log" >&2
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
