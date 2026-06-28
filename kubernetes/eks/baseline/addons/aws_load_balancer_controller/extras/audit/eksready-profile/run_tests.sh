#!/usr/bin/env bash
set -e

echo "🔄 Fetching ephemeral session details from active 'aws login' context..."

# Extract active credentials directly into the script environment
eval $(aws configure export-credentials --format env)

# Resolve region, defaulting to us-west-2 if unassigned in local config
export AWS_REGION=$(aws configure get region)
export AWS_REGION=${AWS_REGION:-"us-east-2"}

echo "📍 Target context resolved: Region=${AWS_REGION}"

echo "🚀 Launching AWS compliance verification sweep..."
inspec exec . -t aws://"${AWS_REGION}" --controls=aws-cluster-version-check

echo "🚀 Launching Kubernetes API compliance verification sweep..."
inspec exec . -t k8s:// --controls=k8s-namespace-check
