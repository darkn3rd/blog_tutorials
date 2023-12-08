#!/usr/bin/env bash
command -v helm > /dev/null || { echo "'helm' command not not found" 1>&2; exit 1; }
[[ -z "${DGRAPH_SC}" ]] && { echo 'DGRAPH_SC not specified. Aborting' 1>&2 ; exit 1; }

DGRAPH_NS=${DGRAPH_NS:-"dgraph"}
DGRAPH_RELEASE_NAME=${DGRAPH_RELEASE_NAME:-"dg"}
DG_ALLOW_LIST=${DG_ALLOW_LIST=:"0.0.0.0/0"}
DGRAPH_ZERO_DISK_SIZE=${DGRAPH_ZERO_DISK_SIZE:-"10Gi"}
DGRAPH_ALPHA_DISK_SIZE=${DGRAPH_ALPHA_DISK_SIZE:-"30Gi"}


# get dgraph helm chart
helm repo add dgraph https://charts.dgraph.io && helm repo update

# deploy dgraph
helm install $DGRAPH_RELEASE_NAME dgraph/dgraph \
  --namespace $DGRAPH_NS \
  --create-namespace \
  --values -  <<EOF
zero:
  persistence:
    storageClass: $DGRAPH_SC
    size: $DGRAPH_ZERO_DISK_SIZE
alpha:
  configFile:
    config.yaml: |
      security:
        whitelist: ${DG_ALLOW_LIST}
  persistence:
    storageClass: $DGRAPH_SC
    size: $DGRAPH_ALPHA_DISK_SIZE
EOF