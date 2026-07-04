#!/usr/bin/env bash
set -euo pipefail

kubectl create deployment demo-gwtcp-app \
  --image=nginx:alpine

kubectl expose deployment demo-gwtcp-app \
  --port=80 \
  --target-port=80

cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-nlb-class
spec:
  controllerName: gateway.k8s.aws/nlb
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-gwtcp-app-gateway
  namespace: demo-gwtcp
spec:
  gatewayClassName: aws-nlb-class
  infrastructure:
    parametersRef:
      group: gateway.k8s.aws
      kind: LoadBalancerConfiguration
      name: demo-gwtcp-app-lb-config
  listeners:
    - name: tcp-80
      protocol: TCP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
        kinds:
          - kind: TCPRoute  
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: demo-gwtcp-app-route
  namespace: demo-gwtcp
spec:
  parentRefs:
    - name: demo-gwtcp-app-gateway
      sectionName: tcp-80
  rules:
    - backendRefs:
        - name: demo-gwtcp-app
          kind: Service
          port: 80
---
apiVersion: gateway.k8s.aws/v1beta1
kind: LoadBalancerConfiguration
metadata:
  name: demo-gwtcp-app-lb-config
  namespace: demo-gwtcp
spec:
  scheme: internet-facing
---
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: demo-gwtcp-app-tg-config
  namespace: demo-gwtcp
spec:
  targetReference:
    group: ""
    kind: Service
    name: demo-gwtcp-app
  defaultConfiguration:
    targetType: ip
EOF