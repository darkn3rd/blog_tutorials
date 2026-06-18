#!/usr/bin/env bash
set -euo pipefail

main() {
  validate_env

  # create network infra
  ./create_eks_network.sh

  # create KUBECONFIG
  mkdir -p $HOME/.kube/aws/
  export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"
  
  # create k8s cluster
  eksctl create cluster -f cluster.yaml
}

validate_env() {
  require_env AWS_PROFILE
  require_env EKS_CLUSTER_NAME
  require_env EKS_REGION
  require_env EKS_VERSION

  if [[ "$EKS_REGION" != "us-east-2" ]]; then
    cat >&2 <<EOF
ERROR: this script currently hardcodes the subnet/AZ layout for us-east-2.

Set:
  export EKS_REGION="us-east-2"
EOF
    exit 1
  fi
}

source ../shared_lib/shell_lib/common.sh

main "$@"
