#!/usr/bin/env bash
# suites/negative_extra_lbs.sh — regression test for the class-name-
# dependent deletion bug this session hit (uninstall_aws_lbc.sh used to
# filter Gateways by a hardcoded gatewayClassName ("aws-nlb" vs the actual
# "aws-nlb-class"), silently leaving non-matching Gateways - and their real
# AWS load balancers - undeleted).
#
# Deploys one Ingress/Service-shaped demo and one Gateway/TCPRoute-shaped
# demo with randomly suffixed names/namespaces (not the 4 canonical demo
# names), so any surviving name-based filtering in the uninstall path would
# miss them.
#
#   - cli-eksctl/cli-aws: left in place for phase 08's uninstall_lbc
#     (uninstall_aws_lbc.sh's wholesale, name-agnostic deletion) to catch -
#     that IS the regression test. If it doesn't, phase 08's verify_clean
#     check fails the whole case.
#   - terraform: terraform destroy only tears down resources in its own
#     state, not ad-hoc kubectl-created objects, so this suite cleans up
#     after itself here instead of relying on phase 08 to catch it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() { echo "❌ $*" >&2; exit 1; }

# shellcheck source=../lib/contract.sh
source "$TESTS_DIR/lib/contract.sh"

: "${INSTALL_METHOD:?INSTALL_METHOD is required}"

SUFFIX="$(date +%s | tail -c 6)$RANDOM"
NLB_NS="demo-x${SUFFIX}nlb"
GW_NS="demo-x${SUFFIX}gw"
GW_CLASS="randclass-${SUFFIX}"

deploy_random_ingress_demo() {
  echo "  Deploying random-named Service/NLB demo in namespace $NLB_NS..."
  kubectl create namespace "$NLB_NS"
  kubectl create deployment "app-${SUFFIX}" --image=nginx:alpine -n "$NLB_NS"
  kubectl expose deployment "app-${SUFFIX}" --port=80 --target-port=80 \
    --type=LoadBalancer -n "$NLB_NS" \
    --dry-run=client --output=yaml \
  | kubectl annotate --filename - \
    "service.beta.kubernetes.io/aws-load-balancer-type=external" \
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type=ip" \
    --local --output=yaml \
  | kubectl apply -f -
}

deploy_random_gateway_demo() {
  echo "  Deploying random-named Gateway/TCPRoute demo (class $GW_CLASS) in namespace $GW_NS..."
  kubectl create namespace "$GW_NS"
  kubectl create deployment "app-${SUFFIX}" --image=nginx:alpine -n "$GW_NS"
  kubectl expose deployment "app-${SUFFIX}" --port=80 --target-port=80 -n "$GW_NS"

  cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: ${GW_CLASS}
spec:
  controllerName: gateway.k8s.aws/nlb
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gw-${SUFFIX}
  namespace: ${GW_NS}
spec:
  gatewayClassName: ${GW_CLASS}
  listeners:
    - name: tcp
      protocol: TCP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: route-${SUFFIX}
  namespace: ${GW_NS}
spec:
  parentRefs:
    - name: gw-${SUFFIX}
  rules:
    - backendRefs:
        - name: app-${SUFFIX}
          port: 80
EOF
}

self_cleanup() {
  echo "  install_method=terraform: cleaning up the random resources directly (terraform destroy won't know about them)..."
  kubectl delete tcproute --all -n "$GW_NS" --ignore-not-found=true
  kubectl delete gateway --all -n "$GW_NS" --ignore-not-found=true
  kubectl delete gatewayclass "$GW_CLASS" --ignore-not-found=true
  kubectl delete namespace "$GW_NS" --ignore-not-found=true
  kubectl delete svc --all -n "$NLB_NS" --ignore-not-found=true
  kubectl delete namespace "$NLB_NS" --ignore-not-found=true
}

deploy_random_ingress_demo
deploy_random_gateway_demo

echo "  Waiting 30s for AWS to begin provisioning..."
sleep 30

case "$INSTALL_METHOD" in
  terraform) self_cleanup ;;
  cli-eksctl|cli-aws)
    echo "  install_method=$INSTALL_METHOD: leaving resources in place for phase 08's wholesale uninstall to catch."
    ;;
  *) die "Unknown install_method '$INSTALL_METHOD'." ;;
esac

echo "  ✅ Random-named resources deployed (namespaces: $NLB_NS, $GW_NS)."
