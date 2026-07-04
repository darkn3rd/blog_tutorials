#!/usr/bin/env bash
set -euo pipefail

kubectl create deployment demo-nlb-app \
  --image=nginx:alpine

kubectl expose deployment demo-nlb-app \
  --port=80 \
  --target-port=80 \
  --type=LoadBalancer \
  --dry-run=client \
  --output yaml \
| kubectl annotate --filename - \
  "service.beta.kubernetes.io/aws-load-balancer-type=external" \
  "service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing" \
  "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type=instance" \
  --local \
  --output yaml \
| kubectl apply --dry-run=client --output yaml --filename -

