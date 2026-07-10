#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0")

Creates all 4 aws-load-balancer-controller demos (mirrors the walkthroughs in
demos/cli/01.svc_nlb .. 04.gw_alb), each in its own namespace:
  - Service/NLB            (namespace: \$SVC_NLB_NAMESPACE)
  - Ingress/ALB            (namespace: \$ING_ALB_NAMESPACE)
  - Gateway+TCPRoute/NLB   (namespace: \$GW_NLB_NAMESPACE)
  - Gateway+HTTPRoute/ALB  (namespace: \$GW_ALB_NAMESPACE)

Verify with ../test_demos.sh afterward.

Options:
  -h, --help   Show this help message and exit

Optional environment variables (defaults match demos/tf/terraform.tfvars):
  SVC_NLB_NAMESPACE   Default: demo-nlb
  ING_ALB_NAMESPACE   Default: demo-alb
  GW_NLB_NAMESPACE    Default: demo-gwtcp
  GW_ALB_NAMESPACE    Default: demo-gwhttp
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "❌ $*" >&2; exit 1; }
# shellcheck source=../../01_cli/scripts/lib/bash_version.sh
source "$SCRIPT_DIR/../../01_cli/scripts/lib/bash_version.sh"
verify_bash

# Every line of output gets a UTC timestamp prefix from here on (after
# --help, so a plain --help invocation stays clean).
# Also dedups repeated tool-progress lines (terraform "Still creating...
# [Ns elapsed]" heartbeats, eksctl repeated "waiting for..." lines) so a
# slow apply doesn't spam the terminal, while any genuinely new/changed
# line (a different resource, a different message) always prints
# immediately. Lines from this script itself (==>/status markers) print
# as-is; everything else is indented to show it's from the underlying
# tool, not this script.
_tool_output_filter() {
  local _lf_last="" _lf_last_ts=0
  while IFS= read -r _line; do
    local _lf_now _lf_norm
    _lf_now=$(date +%s)
    _lf_norm="$(printf '%s' "$_line" | sed -E \
      -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T? ?[0-9]{2}:[0-9]{2}:[0-9]{2}Z? *//' \
      -e 's/[0-9]+m[0-9]+s elapsed/Ns elapsed/' \
      -e 's/\[[0-9]+s elapsed\]/[Ns elapsed]/')"
    if [[ "$_lf_norm" == "$_lf_last" ]] && (( _lf_now - _lf_last_ts < 30 )); then
      continue
    fi
    _lf_last="$_lf_norm"; _lf_last_ts="$_lf_now"
    case "$_line" in
      "==>"*|"✅"*|"❌"*|"⚠️"*|"─────"*|"====="*|"")
        printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
      *)
        printf '[%s]     | %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
    esac
  done
}
exec > >(_tool_output_filter) 2>&1

SVC_NLB_NAMESPACE="${SVC_NLB_NAMESPACE:-demo-nlb}"
ING_ALB_NAMESPACE="${ING_ALB_NAMESPACE:-demo-alb}"
GW_NLB_NAMESPACE="${GW_NLB_NAMESPACE:-demo-gwtcp}"
GW_ALB_NAMESPACE="${GW_ALB_NAMESPACE:-demo-gwhttp}"

setup_namespace() {
  local ns="$1"
  echo "==> Creating namespace $ns..."
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  kubectl config set-context --current --namespace="$ns"
}

deploy_app() {
  local ns="$1" app_name="$2"
  echo "==> Deploying $app_name in $ns..."
  kubectl create deployment "$app_name" --image=nginx:alpine -n "$ns" --dry-run=client -o yaml | kubectl apply -f -
}

expose_clusterip() {
  local ns="$1" app_name="$2"
  echo "==> Exposing $app_name as ClusterIP in $ns..."
  kubectl expose deployment "$app_name" --port=80 --target-port=80 -n "$ns" --dry-run=client -o yaml | kubectl apply -f -
}

create_svc_nlb() {
  local ns="$SVC_NLB_NAMESPACE"
  setup_namespace "$ns"
  deploy_app "$ns" "demo-nlb-app"

  echo "==> Creating NLB Service in $ns..."
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-type: external
  labels:
    app: demo-nlb-app
  name: demo-nlb-app
  namespace: $ns
spec:
  ports:
  - port: 80
  selector:
    app: demo-nlb-app
  type: LoadBalancer
EOF
}

create_ing_alb() {
  local ns="$ING_ALB_NAMESPACE"
  setup_namespace "$ns"
  deploy_app "$ns" "demo-alb-app"
  expose_clusterip "$ns" "demo-alb-app"

  echo "==> Creating ALB Ingress in $ns..."
  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
  name: demo-alb-app
  namespace: $ns
spec:
  rules:
  - host: demo.example.com
    http:
      paths:
      - backend:
          service:
            name: demo-alb-app
            port:
              number: 80
        path: /
        pathType: Prefix
EOF
}

create_gw_nlb() {
  local ns="$GW_NLB_NAMESPACE"
  setup_namespace "$ns"
  deploy_app "$ns" "demo-gwtcp-app"
  expose_clusterip "$ns" "demo-gwtcp-app"

  echo "==> Creating Gateway + TCPRoute (NLB) in $ns..."
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
  namespace: $ns
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
  namespace: $ns
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
  namespace: $ns
spec:
  scheme: internet-facing
---
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: demo-gwtcp-app-tg-config
  namespace: $ns
spec:
  targetReference:
    group: ""
    kind: Service
    name: demo-gwtcp-app
  defaultConfiguration:
    targetType: ip
EOF
}

create_gw_alb() {
  local ns="$GW_ALB_NAMESPACE"
  setup_namespace "$ns"
  deploy_app "$ns" "demo-gwhttp-app"
  expose_clusterip "$ns" "demo-gwhttp-app"

  echo "==> Creating Gateway + HTTPRoute (ALB) in $ns..."
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
  namespace: $ns
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
  namespace: $ns
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
  namespace: $ns
spec:
  scheme: internet-facing
---
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: demo-gwhttp-app-tg-config
  namespace: $ns
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
}

main() {
  create_svc_nlb
  create_ing_alb
  create_gw_nlb
  create_gw_alb
  kubectl config set-context --current --namespace=default

  echo
  echo "All demos created. Verify with: ../test_demos.sh"
}

main "$@"
