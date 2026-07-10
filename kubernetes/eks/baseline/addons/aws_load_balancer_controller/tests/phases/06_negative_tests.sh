#!/usr/bin/env bash
# phases/06_negative_tests.sh — dispatcher over tests/suites/*.sh. No-op if
# $NEGATIVE_SUITES is empty (bare --case/--all runs, or a tier whose suites
# list is just "positive").
#
# Required env: NEGATIVE_SUITES - space-separated suite names, e.g.
# "negative-collision negative-extra-lbs" (hyphenated; mapped to
# suites/negative_collision.sh etc.)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${INSTALL_METHOD:?INSTALL_METHOD is required}"
: "${AUTH_MODE:?AUTH_MODE is required}"

NEGATIVE_SUITES="${NEGATIVE_SUITES:-}"

if [[ -z "$NEGATIVE_SUITES" ]]; then
  echo "No negative suites requested for this case - skipping."
  exit 0
fi

rc=0
for suite in $NEGATIVE_SUITES; do
  suite_file="$TESTS_DIR/suites/${suite//-/_}.sh"
  [[ -f "$suite_file" ]] || die "Unknown suite '$suite' - no $suite_file."
  echo "==> Running suite: $suite"
  if ! "$suite_file"; then
    echo "❌ Suite failed: $suite" >&2
    rc=1
  else
    echo "✅ Suite passed: $suite"
  fi
done

exit $rc
