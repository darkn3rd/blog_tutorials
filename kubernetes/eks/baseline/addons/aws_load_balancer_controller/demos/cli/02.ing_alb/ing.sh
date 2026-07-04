#!/usr/bin/env bash
set -euo pipefail

kubectl create deployment demo-alb-app \
  --image=nginx:alpine
kubectl expose deployment demo-alb-app --port=80

kubectl create ingress demo-alb-app \
  --rule="demo.example.com/*=demo-alb-app:80" \
  --dry-run=client \
  --output yaml \
| kubectl annotate --filename - \
    kubernetes.io/ingress.class=alb \
    alb.ingress.kubernetes.io/scheme=internet-facing \
    alb.ingress.kubernetes.io/target-type=ip \
    --local \
    --output yaml \
| kubectl apply --filename -


