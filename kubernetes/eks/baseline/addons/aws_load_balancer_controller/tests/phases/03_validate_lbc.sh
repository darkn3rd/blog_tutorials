#!/usr/bin/env bash
# phases/03_validate_lbc.sh — validates CRDs, IAM policy, and auth binding.
# Install-method-agnostic - see lib/contract.sh's validate_lbc().
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

validate_lbc
