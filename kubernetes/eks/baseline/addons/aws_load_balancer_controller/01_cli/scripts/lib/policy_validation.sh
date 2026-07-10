#!/usr/bin/env bash
# lib/policy_validation.sh — IAM policy fingerprinting and statement validation.
# Source this file; do not execute it directly.
#
# Requires: jq, diff
# Assumes:  die(), EXPECTED_POLICY_JSON are defined by the sourcing script.
#           fetch_live_policy() is available (from lib/aws.sh).

# ── Statement fingerprinting ──────────────────────────────────────────────────
#
# A fingerprint is a normalised, order-independent JSON string representing a
# statement for comparison purposes:
#
#   Effect    : kept as-is
#   Action    : sorted array (strings coerced to array first)
#   Resource  : sorted array (strings coerced to array first)
#   Condition : keys sorted at every level; absent Condition → explicit null
#
# Two statements with the same actions in different order are considered equal.
# Two statements that differ only in Condition are always considered unequal.

# fingerprint_statement <json-statement> → stdout (normalised JSON, compact)
fingerprint_statement() {
  local stmt="${1:?stmt is required}"
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

# build_fingerprint_map <policy-json> <nameref-assoc-array>
# Populates nameref with: fingerprint → original statement JSON
build_fingerprint_map() {
  local policy="${1:?policy is required}"
  local -n _map="${2:?nameref is required}"
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

# ── Diff formatting ───────────────────────────────────────────────────────────

# pretty_diff <expected-stmt-json> <actual-stmt-json|"">
# Prints a unified diff between expected and actual.
# If actual is empty (no match found), prints expected only with a note.
pretty_diff() {
  local expected="${1:?expected is required}"
  local actual="${2:-}"

  local exp_pretty
  exp_pretty=$(echo "$expected" | jq '.')

  if [[ -z "$actual" ]]; then
    echo "    Expected statement (no match found in live policy):"
    echo "$exp_pretty" | sed 's/^/    /'
    return
  fi

  local act_pretty
  act_pretty=$(echo "$actual" | jq '.')

  diff --unified=3 \
    <(echo "$exp_pretty") \
    <(echo "$act_pretty") \
    | tail -n +4 \
    | sed 's/^-/    − /; s/^+/    + /; s/^ /      /' \
    || true  # diff exits 1 on differences — expected here
}

# ── Core validation ───────────────────────────────────────────────────────────

# validate_policy <policy-arn>
# Fetches the live policy and verifies every statement in EXPECTED_POLICY_JSON
# is present. Prints a grouped summary, then per-statement diffs on failure.
# Returns 0 if all statements match, 1 otherwise.
validate_policy() {
  local policy_arn="${1:?policy_arn is required}"

  echo "  Fetching live policy document..."
  local live_policy
  live_policy=$(fetch_live_policy "$policy_arn")

  local -A live_fps=()
  build_fingerprint_map "$live_policy" live_fps

  local expected_count
  expected_count=$(echo "$EXPECTED_POLICY_JSON" | jq '.Statement | length')

  local -a failed_indices=()
  local -A failed_expected=()   # index → expected stmt JSON
  local -A failed_actual=()     # index → closest actual stmt JSON (may be empty)

  echo ""
  echo "  Required Statements  ($expected_count total)"
  echo "  ──────────────────────────────────────────"

  for (( i=0; i<expected_count; i++ )); do
    local exp_stmt exp_fp first_action action_count resource_label label
    exp_stmt=$(echo "$EXPECTED_POLICY_JSON" | jq ".Statement[$i]")
    exp_fp=$(fingerprint_statement "$exp_stmt")

    first_action=$(echo "$exp_stmt" | jq -r '
      if (.Action | type) == "string" then .Action else .Action[0] end')
    action_count=$(echo "$exp_stmt" | jq '
      if (.Action | type) == "string" then 1 else .Action | length end')
    resource_label=$(echo "$exp_stmt" | jq -r '
      if (.Resource | type) == "string" then .Resource
      elif (.Resource | length) == 1 then .Resource[0]
      else "[\(.Resource | length) resources]" end' \
      | sed 's|arn:aws:[^:]*:[^:]*:[^:]*:||')

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

      # Closest-match heuristic: find a live statement sharing the first action
      local closest="" live_fp
      for live_fp in "${!live_fps[@]}"; do
        local live_first
        live_first=$(echo "${live_fps[$live_fp]}" | jq -r '
          if (.Action | type) == "string" then .Action else .Action[0] end')
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
