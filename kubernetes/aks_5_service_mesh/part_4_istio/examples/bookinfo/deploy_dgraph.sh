#!/usr/bin/env bash

command -v kubectl > /dev/null || \
  { echo "[ERROR]: 'kubectl' command not not found" 1>&2; exit 1; }

HELMFILE=${HELMFILE:-"$(dirname $0)/helmfile.yaml"}

kubectl get namespace "bookinfo" > /dev/null 2> /dev/null || \
 kubectl create namespace "bookinfo" && \
 kubectl label namespaces "bookinfo" name="bookinfo"
kubectl label namespace "bookinfo" istio-injection="enabled"

kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.10/samples/bookinfo/platform/kube/bookinfo.yaml
