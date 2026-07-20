#!/usr/bin/env bash
# lib/yaml.sh — matrix.yaml reader, backed by yq (mikefarah/yq v4).
# Source this file; do not execute it directly.
#
# Assumes: die() is defined by the sourcing script; MATRIX_FILE points at
# matrix.yaml (default: tests/matrix.yaml relative to this file).

MATRIX_FILE="${MATRIX_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/matrix.yaml}"

verify_yq() {
  command -v yq >/dev/null 2>&1 || die "yq (mikefarah/yq v4) is required but not found in PATH."
  [[ -f "$MATRIX_FILE" ]] || die "matrix.yaml not found at: $MATRIX_FILE"
}

# matrix_cluster_field <field> -> stdout
matrix_cluster_field() {
  local field="${1:?field is required}"
  yq eval ".cluster.${field}" "$MATRIX_FILE"
}

# matrix_all_case_names -> stdout, one per line
matrix_all_case_names() {
  yq eval '.cases[].name' "$MATRIX_FILE"
}

# matrix_case_exists <name> -> 0/1
matrix_case_exists() {
  local name="${1:?name is required}"
  local found
  found="$(yq eval ".cases[] | select(.name == \"${name}\") | .name" "$MATRIX_FILE")"
  [[ -n "$found" ]]
}

# matrix_case_field <name> <field> -> stdout
matrix_case_field() {
  local name="${1:?name is required}"
  local field="${2:?field is required}"
  yq eval ".cases[] | select(.name == \"${name}\") | .${field}" "$MATRIX_FILE"
}

# matrix_all_tier_names -> stdout, one per line
matrix_all_tier_names() {
  yq eval '.tiers | keys | .[]' "$MATRIX_FILE"
}

# matrix_tier_exists <tier> -> 0/1
matrix_tier_exists() {
  local tier="${1:?tier is required}"
  local val
  val="$(yq eval ".tiers.${tier} // \"\"" "$MATRIX_FILE")"
  [[ -n "$val" ]]
}

# matrix_tier_cases <tier> -> stdout, one case name per line
# Expands the tier's literal "all" to every case in matrix.yaml.
matrix_tier_cases() {
  local tier="${1:?tier is required}"
  local raw
  raw="$(yq eval ".tiers.${tier}.cases" "$MATRIX_FILE")"
  if [[ "$raw" == "all" ]]; then
    matrix_all_case_names
  else
    yq eval ".tiers.${tier}.cases[]" "$MATRIX_FILE"
  fi
}

# matrix_tier_suites <tier> -> stdout, one suite name per line
# Expands the tier's literal "all" to every tests/suites/*.sh file (minus
# "positive", which isn't a suite script - it's the always-run base flow).
matrix_tier_suites() {
  local tier="${1:?tier is required}"
  local raw
  raw="$(yq eval ".tiers.${tier}.suites" "$MATRIX_FILE")"
  if [[ "$raw" == "all" ]]; then
    echo "positive"
    local suites_dir
    suites_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/suites"
    local f name
    for f in "$suites_dir"/*.sh; do
      [[ -e "$f" ]] || continue
      name="$(basename "$f" .sh)"
      echo "${name//_/-}"
    done
  else
    yq eval ".tiers.${tier}.suites[]" "$MATRIX_FILE"
  fi
}
