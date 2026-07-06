#!/usr/bin/env bash
set -e

# cinc-auditor and inspec are wire-compatible; prefer cinc-auditor (pure
# open source) if it's on PATH, otherwise fall back to inspec.
RUNNER="inspec"
command -v cinc-auditor >/dev/null 2>&1 && RUNNER="cinc-auditor"

echo "🚀 Launching stage 4 (demos-ready) compliance sweep via ${RUNNER}..."
"$RUNNER" exec . -t k8s://
