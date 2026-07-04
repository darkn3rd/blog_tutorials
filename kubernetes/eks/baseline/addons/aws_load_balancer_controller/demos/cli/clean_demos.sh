#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0")

Removes all 4 aws-load-balancer-controller demos created by create_demos.sh:
deletes the load balancer resources (Service/Ingress/Gateway+Route), waits for
AWS to deprovision the load balancers, then deletes each demo's namespace.

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

SVC_NLB_NAMESPACE="${SVC_NLB_NAMESPACE:-demo-nlb}"
ING_ALB_NAMESPACE="${ING_ALB_NAMESPACE:-demo-alb}"
GW_NLB_NAMESPACE="${GW_NLB_NAMESPACE:-demo-gwtcp}"
GW_ALB_NAMESPACE="${GW_ALB_NAMESPACE:-demo-gwhttp}"

# name|namespace|gatewayclass (gatewayclass is cluster-scoped, deleted by name - never via --all)
DEMOS=(
  "Service/NLB|$SVC_NLB_NAMESPACE|"
  "Ingress/ALB|$ING_ALB_NAMESPACE|"
  "Gateway+TCPRoute/NLB|$GW_NLB_NAMESPACE|aws-nlb-class"
  "Gateway+HTTPRoute/ALB|$GW_ALB_NAMESPACE|aws-alb"
)

clean_namespace() {
  local name="$1" ns="$2" gatewayclass="$3"

  echo
  echo "===== Cleaning $name (namespace: $ns) ====="

  if ! kubectl get namespace "$ns" &>/dev/null; then
    echo "Namespace $ns not found, skipping."
    return 0
  fi

  echo "Deleting namespaced Gateway API resources (if any)..."
  kubectl delete gateway,httproute,tcproute --all -n "$ns" --ignore-not-found=true 2>/dev/null || true
  kubectl delete loadbalancerconfiguration,targetgroupconfiguration --all -n "$ns" --ignore-not-found=true 2>/dev/null || true

  echo "Deleting Ingress/Service/Deployment..."
  kubectl delete ingress,svc,deployment --all -n "$ns" --ignore-not-found=true

  echo "Waiting for load balancer to deprovision..."
  sleep 30

  if [[ -n "$gatewayclass" ]]; then
    echo "Deleting GatewayClass $gatewayclass (cluster-scoped)..."
    kubectl delete gatewayclass "$gatewayclass" --ignore-not-found=true 2>/dev/null || true
  fi

  echo "Deleting namespace $ns..."
  kubectl delete namespace "$ns" --ignore-not-found=true
}

main() {
  for demo in "${DEMOS[@]}"; do
    IFS='|' read -r name ns gatewayclass <<< "$demo"
    clean_namespace "$name" "$ns" "$gatewayclass"
  done

  kubectl config set-context --current --namespace=default

  echo
  echo "All demo namespaces cleaned up."
}

main "$@"
