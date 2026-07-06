#!/usr/bin/env bash
set -e

# cinc-auditor and inspec are wire-compatible; prefer cinc-auditor (pure
# open source) if it's on PATH, otherwise fall back to inspec.
RUNNER="inspec"
command -v cinc-auditor >/dev/null 2>&1 && RUNNER="cinc-auditor"

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"

echo "🔄 Fetching ephemeral session details from active 'aws login' context..."

# Extract active credentials directly into the script environment
eval $(aws configure export-credentials --format env)

# Resolve region, defaulting to us-west-2 if unassigned in local config
export AWS_REGION=$(aws configure get region)
export AWS_REGION=${AWS_REGION:-"us-east-2"}

echo "📍 Target context resolved: Region=${AWS_REGION}, Cluster=${EKS_CLUSTER_NAME}"

# A single -t k8s:// run covers both the aws_* and k8s_* resources used here:
# aws_* resources talk to AWS directly via the SDK regardless of -t, while
# k8s_* resources need the k8s:// transport to reach the cluster.
echo "🚀 Launching stage 2 (bindings-ready) compliance sweep via ${RUNNER}..."
"$RUNNER" exec . -t k8s://
