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
    storageClass: ebs-sc
alpha:
  configFile:
    config.yaml: |
      security:
        whitelist: ${DG_ALLOW_LIST}
  persistence:
    storageClass: ebs-sc
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
      service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=true
EOF
