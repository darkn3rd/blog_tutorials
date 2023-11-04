#!/usr/bin/env bash

## Check for required commands
command -v helm > /dev/null || { echo "'helm' command not not found" 1>&2; exit 1; }

DG_ALLOW_LIST=${DG_ALLOW_LIST:-'0.0.0.0/0'}

# get dgraph helm chart
helm repo add dgraph https://charts.dgraph.io && helm repo update

# deploy dgraph
helm install dg dgraph/dgraph \
  --namespace dgraph \
  --create-namespace \
  --values -  <<EOF
zero:
  persistence:
    storageClass: premium-rwo
    size: 10Gi
alpha:
  configFile:
    config.yaml: |
      security:
        whitelist: ${DG_ALLOW_LIST}
  persistence:
    storageClass: premium-rwo
    size: 30Gi
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local
EOF