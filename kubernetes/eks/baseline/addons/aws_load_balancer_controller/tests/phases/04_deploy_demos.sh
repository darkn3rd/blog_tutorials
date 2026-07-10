#!/usr/bin/env bash
# phases/04_deploy_demos.sh — deploys the 4 canonical demos (NLB Service,
# ALB Ingress, Gateway+TCPRoute NLB, Gateway+HTTPRoute ALB).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

deploy_demos
