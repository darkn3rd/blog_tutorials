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

kubectl get namespace "pydgraph-client" > /dev/null 2> /dev/null || \
 kubectl create namespace "pydgraph-client" && \
 kubectl label namespaces "pydgraph-client" name="pydgraph-client" && \
 kubectl label namespace "pydgraph-client" istio-injection="enabled"

helmfile --file $HELMFILE apply
