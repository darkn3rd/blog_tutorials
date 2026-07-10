#!/usr/bin/env bash
# lib/log.sh — per-phase log capture and summary.json emission.
# Source this file; do not execute it directly.
#
# Requires: jq
# Assumes: die() is defined by the sourcing script.

# Canonical per-case phase order/keys, in the order they run. 00/09
# (provision/destroy cluster) are run-scoped, not per-case, and are logged
# separately by run_matrix.sh directly - they don't appear here.
readonly -a CASE_PHASE_KEYS=(
  preflight
  install
  validate_lbc
  deploy_demos
  validate_demos
  negative_tests
  cleanup_demos
  uninstall_lbc
)

declare -gA PHASE_RESULT=()
declare -gA PHASE_LOG=()
declare -gA PHASE_DURATION=()

# log_reset_case — clears per-case phase tracking state. Call once before
# running a new case's phases.
log_reset_case() {
  PHASE_RESULT=()
  PHASE_LOG=()
  PHASE_DURATION=()
}

# run_logged_phase <case_dir> <phase_key> <log_filename> <command...>
# Runs <command...>, teeing combined stdout/stderr to
# <case_dir>/<log_filename>, and records the result into PHASE_RESULT/
# PHASE_LOG/PHASE_DURATION under <phase_key> for write_case_summary().
# Returns the command's exit code (does not itself fail the caller - the
# caller decides what a non-zero phase means).
run_logged_phase() {
  local case_dir="${1:?case_dir is required}"
  local phase_key="${2:?phase_key is required}"
  local log_filename="${3:?log_filename is required}"
  shift 3

  mkdir -p "$case_dir"
  local log_path="$case_dir/$log_filename"
  local start_ts end_ts rc

  echo "───── [$phase_key] $(date -u +%FT%TZ) ─────" > "$log_path"
  start_ts=$(date +%s)

  # No set -e anywhere in this framework, so no set +e/-e guard is needed
  # here - and adding one would be actively wrong: `set -e`/`set +e` are not
  # function-scoped in bash, so toggling it inside this function would leak
  # out and change the *caller's* shell options for the rest of its life,
  # potentially killing it on this function's own return value if the call
  # site isn't wrapped in if/||.
  "$@" >>"$log_path" 2>&1
  rc=$?

  end_ts=$(date +%s)
  echo "───── [$phase_key] $(date -u +%FT%TZ) - exit $rc, $((end_ts - start_ts))s ─────" >> "$log_path"

  PHASE_RESULT["$phase_key"]=$([[ $rc -eq 0 ]] && echo "pass" || echo "fail")
  PHASE_LOG["$phase_key"]="$log_filename"
  PHASE_DURATION["$phase_key"]=$((end_ts - start_ts))

  if [[ $rc -eq 0 ]]; then
    echo "  ✅ $phase_key ($(( end_ts - start_ts ))s)"
  else
    echo "  ❌ $phase_key ($(( end_ts - start_ts ))s) - see $log_path"
  fi

  return "$rc"
}

# log_skip_phase <phase_key> <reason>
# Marks a phase as skipped (e.g. no negative suites requested for this
# case/tier) without running anything or writing a log file.
log_skip_phase() {
  local phase_key="${1:?phase_key is required}"
  local reason="${2:-not applicable}"
  PHASE_RESULT["$phase_key"]="skip"
  PHASE_LOG["$phase_key"]=""
  PHASE_DURATION["$phase_key"]=0
  echo "  ⏭  $phase_key skipped ($reason)"
}

# write_case_summary <case_dir> <case_name> <install_method> <auth_mode> <suites_csv>
# Emits <case_dir>/summary.json from the PHASE_RESULT/PHASE_LOG/
# PHASE_DURATION state accumulated by run_logged_phase()/log_skip_phase()
# since the last log_reset_case(). Overall "result" is "fail" if any phase
# is "fail", "pass" if every phase is "pass" or "skip".
write_case_summary() {
  local case_dir="${1:?case_dir is required}"
  local case_name="${2:?case_name is required}"
  local install_method="${3:?install_method is required}"
  local auth_mode="${4:?auth_mode is required}"
  local suites_csv="${5:-}"

  local overall="pass"
  local phases_json="{}"
  local key

  for key in "${CASE_PHASE_KEYS[@]}"; do
    local result="${PHASE_RESULT[$key]:-skip}"
    local log="${PHASE_LOG[$key]:-}"
    local duration="${PHASE_DURATION[$key]:-0}"
    [[ "$result" == "fail" ]] && overall="fail"

    phases_json="$(echo "$phases_json" | jq \
      --arg key "$key" \
      --arg result "$result" \
      --arg log "$log" \
      --argjson duration "$duration" \
      '.[$key] = {result: $result, duration_s: $duration, log: $log}')"
  done

  local suites_json
  if [[ -n "$suites_csv" ]]; then
    suites_json="$(printf '%s\n' "${suites_csv//,/$'\n'}" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
  else
    suites_json="[]"
  fi

  jq -n \
    --arg case "$case_name" \
    --arg install_method "$install_method" \
    --arg auth_mode "$auth_mode" \
    --argjson suites "$suites_json" \
    --arg result "$overall" \
    --argjson phases "$phases_json" \
    '{
      case: $case,
      install_method: $install_method,
      auth_mode: $auth_mode,
      suites: $suites,
      result: $result,
      phases: $phases
    }' > "$case_dir/summary.json"

  echo "$overall"
}
