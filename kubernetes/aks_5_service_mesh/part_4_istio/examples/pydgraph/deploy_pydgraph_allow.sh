#!/usr/bin/env bash

command -v helm > /dev/null || \
  { echo "[ERROR]: 'helm' command not not found" 1>&2; exit 1; }
command -v helmfile > /dev/null || \
  { echo "[ERROR]: 'helmfile' command not not found" 1>&2; exit 1; }
command -v kubectl > /dev/null || \
  { echo "[ERROR]: 'kubectl' command not not found" 1>&2; exit 1; }

HELMFILE=${HELMFILE:-"$(dirname $0)/helmfile.yaml"}

kubectl get namespace "pydgraph-allow" > /dev/null 2> /dev/null || \
 kubectl create namespace "pydgraph-allow" && \
 kubectl label namespaces "pydgraph-allow" name="pydgraph-allow"
kubectl label namespace "pydgraph-allow" istio-injection="enabled"
helmfile --namespace "pydgraph-allow" --file $HELMFILE apply
