#!/usr/bin/env bash

command -v kubectl > /dev/null || \
  { echo "[ERROR]: 'kubectl' command not not found" 1>&2; exit 1; }

ADDONS=${ADDONS:-"$(dirname $0)/../addons"}

VER="1.10"
PREFIX="raw.githubusercontent.com/istio/istio/release-${VER}/samples/addons/"
MANIFESTS=("grafana" "jaeger" "kiali" "prometheus" "prometheus_vm" "prometheus_vm_tls")

for MANIFEST in ${MANIFESTS[*]}; do
  curl --silent \
    --location "https://${PREFIX}/${MANIFEST}.yaml" \
    --output ${ADDONS}/${MANIFEST}.yaml
done

kubectl apply --filename ${ADDONS}
