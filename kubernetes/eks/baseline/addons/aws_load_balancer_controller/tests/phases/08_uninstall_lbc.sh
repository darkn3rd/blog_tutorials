#!/usr/bin/env bash
# phases/08_uninstall_lbc.sh — uninstalls LBC via the case's install_method,
# then asserts full teardown via verify_clean(). This is the phase that
# actually proves the case's uninstall path works, not just that it exited 0.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${INSTALL_METHOD:?INSTALL_METHOD is required}"
: "${AUTH_MODE:?AUTH_MODE is required}"

uninstall_lbc "$INSTALL_METHOD" "$AUTH_MODE"

echo "==> Verifying clean teardown..."
verify_clean "$INSTALL_METHOD" || die "uninstall_lbc completed but resources remain - see above."
echo "✅ Fully clean."
