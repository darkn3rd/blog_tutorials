#!/usr/bin/env bash

## Check for required commands
command -v kubectl > /dev/null || { echo "'kubectl' command not not found" 1>&2; exit 1; }

## deploy application
kubectl create namespace httpd-svc
kubectl create deployment httpd \
  --image=httpd \
  --replicas=3 \
  --port=80 \
  --namespace=httpd-svc

## provision external load balancer
cat <<EOF | kubectl apply --namespace httpd-svc -f -
apiVersion: v1
kind: Service
metadata:
  name: httpd
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: LoadBalancer
  selector:
    app: httpd
EOF