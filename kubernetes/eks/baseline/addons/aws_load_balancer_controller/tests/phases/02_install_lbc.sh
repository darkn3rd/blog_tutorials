#!/usr/bin/env bash
# phases/02_install_lbc.sh — installs LBC via the case's install_method/auth_mode.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${INSTALL_METHOD:?INSTALL_METHOD is required}"
: "${AUTH_MODE:?AUTH_MODE is required}"

install_lbc "$INSTALL_METHOD" "$AUTH_MODE"
