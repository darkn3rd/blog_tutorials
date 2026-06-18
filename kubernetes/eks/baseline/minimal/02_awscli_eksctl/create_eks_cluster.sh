#!/usr/bin/env bash
set -euo pipefail

source ../shared_lib/shell_lib/common.sh

main() {
  validate_env

  # Load generated network IDs
  source ./vpc-outputs.env

  # Sanity check network/config before creating EKS
  ./validate_eks_network.sh

  mkdir -p "$HOME/.kube/aws"
  export KUBECONFIG="$HOME/.kube/aws/$EKS_REGION.$EKS_CLUSTER_NAME.yaml"

  eksctl create cluster --config-file cluster.yaml
}

validate_env() {
  require_envs AWS_PROFILE EKS_CLUSTER_NAME EKS_REGION EKS_VERSION
  require_commands aws eksctl

  [[ -f ./vpc-outputs.env ]] \
    || die "missing ./vpc-outputs.env; run ./create_eks_network.sh first"
  [[ -f ./cluster.yaml ]] \
    || die "missing ./cluster.yaml; run ./create_eks_network.sh first"
}


main "$@"
