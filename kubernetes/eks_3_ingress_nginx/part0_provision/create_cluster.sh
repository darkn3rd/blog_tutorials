#!/usr/bin/env bash
command -v eksctl > /dev/null || \
  { echo 'eksctl command not not found' 1>&2; exit 1; }

## default settings
MY_CLUSTER_NAME=${1:-"my-ingress-demo-cluster"}
MY_REGION=${2:-"us-west-2"}
MY_VERSION=${3:-"1.14"}

## create eksctl config from template
sed -e "s/\$MY_CLUSTER_NAME/$MY_CLUSTER_NAME/" \
    -e "s/\$MY_REGION/$MY_REGION/" \
    -e "s/\$MY_VERSION/$MY_VERSION/" \
    template_cluster.yaml > cluster.yaml

## provision eks from eksctl config
eksctl create cluster \
  --config-file "cluster.yaml" \
  --kubeconfig="demo-cluster-config.yaml"
