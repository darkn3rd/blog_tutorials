#!/usr/bin/env bash

## Check for required commands
command -v helm > /dev/null || { echo "'helm' command not not found" 1>&2; exit 1; }

# get Ratel helm chart
helm repo add dgraph https://charts.dgraph.io && helm repo update

# deploy Ratel
helm install ratel \
  --namespace ratel \
  --create-namespace dgraph/ratel \
  --values - <<EOF
service:
  type: NodePort
ingress:
  enabled: true
  className: gce
  annotations:
    kubernetes.io/ingress.class: gce
  hosts:
    - paths:
        - path: /*
          pathType: ImplementationSpecific
EOF
