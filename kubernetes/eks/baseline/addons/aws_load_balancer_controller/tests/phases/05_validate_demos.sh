#!/usr/bin/env bash
# phases/05_validate_demos.sh — curls each demo's load balancer and expects HTTP 2xx.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

validate_demos
