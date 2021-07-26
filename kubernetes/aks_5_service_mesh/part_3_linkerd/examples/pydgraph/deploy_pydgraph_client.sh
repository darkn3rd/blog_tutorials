#!/usr/bin/env bash

command -v helm > /dev/null || \
  { echo "[ERROR]: 'helm' command not not found" 1>&2; exit 1; }
command -v helmfile > /dev/null || \
  { echo "[ERROR]: 'helmfile' command not not found" 1>&2; exit 1; }
command -v kubectl > /dev/null || \
  { echo "[ERROR]: 'kubectl' command not not found" 1>&2; exit 1; }
command -v linkerd > /dev/null || \
  { echo "[ERROR]: 'linkerd' command not not found" 1>&2; exit 1; }

HELMFILE=${HELMFILE:-"$(dirname $0)/helmfile.yaml"}

kubectl get namespace "pydgraph-client" 2>&1  > /dev/null || \
  kubectl create namespace "pydgraph-client"

helmfile --file $HELMFILE template | \
  linkerd inject - | \
  kubectl apply --namespace "pydgraph-client" --filename -
