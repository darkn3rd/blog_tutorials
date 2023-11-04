#!/usr/bin/env bash

## Check for required commands
command -v helm > /dev/null || { echo "'helm' command not not found" 1>&2; exit 1; }

# get dgraph helm chart
helm repo add dgraph https://charts.dgraph.io && helm repo update

# deploy Ratel
helm install ratel \
  --namespace ratel \
  --create-namespace dgraph/ratel \
  --values - <<EOF
ingress:
  enabled: true
  className: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
  hosts:
    - paths:
        - path: /*
          pathType: ImplementationSpecific
EOF
