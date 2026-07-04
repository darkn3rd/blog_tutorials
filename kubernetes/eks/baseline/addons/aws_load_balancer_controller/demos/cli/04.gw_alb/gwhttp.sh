#!/usr/bin/env bash
set -euo pipefail

kubectl create deployment demo-gwhttp-app \
  --image=nginx:alpine

kubectl expose deployment demo-gwhttp-app \
  --port=80 \
  --target-port=80

cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-gwhttp-app-gw
spec:
  gatewayClassName: aws-alb
  infrastructure:
    parametersRef:
      group: gateway.k8s.aws
      kind: LoadBalancerConfiguration
      name: demo-gwhttp-app-lb-config
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: demo-gwhttp-app-route
spec:
  hostnames:
    - demo.example.com
  parentRefs:
    - name: demo-gwhttp-app-gw
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: demo-gwhttp-app
          port: 80
---
apiVersion: gateway.k8s.aws/v1beta1
kind: LoadBalancerConfiguration
metadata:
  name: demo-gwhttp-app-lb-config
spec:
  scheme: internet-facing
---
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: demo-gwhttp-app-tg-config
spec:
  defaultConfiguration:
    targetType: ip
    healthCheckConfig:
      healthCheckProtocol: HTTP
      healthCheckPort: "80"
      healthCheckPath: /
  targetReference:
    group: ""
    kind: Service
    name: demo-gwhttp-app
EOF