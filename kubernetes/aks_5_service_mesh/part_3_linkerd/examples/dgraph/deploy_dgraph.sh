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

kubectl get namespace "dgraph" > /dev/null 2> /dev/null || \
 kubectl create namespace "dgraph" && \
 kubectl label namespaces "dgraph" name="dgraph"

helmfile --file $HELMFILE template | \
  linkerd inject \
    --registry $LINKERD_REGISTRY \
    --skip-inbound-ports 5080,7080 \
    --skip-outbound-ports 5080,7080 - | \
  kubectl apply --namespace "dgraph" --filename -
