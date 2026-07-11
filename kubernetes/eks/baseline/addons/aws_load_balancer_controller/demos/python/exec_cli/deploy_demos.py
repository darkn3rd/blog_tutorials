#!/usr/bin/env python3
"""deploy_demos.py — Creates all 4 aws-load-balancer-controller demos, each in
its own namespace, by calling `kubectl` via subprocess:
  - Service/NLB            (namespace: $SVC_NLB_NAMESPACE)
  - Ingress/ALB             (namespace: $ING_ALB_NAMESPACE)
  - Gateway+TCPRoute/NLB    (namespace: $GW_NLB_NAMESPACE)
  - Gateway+HTTPRoute/ALB   (namespace: $GW_ALB_NAMESPACE)

Verify with ../../test_demos.sh afterward.

Works against a cluster with the AWS Load Balancer Controller installed,
however that install happened.

Requires: kubectl on PATH; Python >= 3.9.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

MIN_PYTHON = (3, 9)
if sys.version_info < MIN_PYTHON:
    found = ".".join(str(p) for p in sys.version_info[:3])
    required = ".".join(str(p) for p in MIN_PYTHON)
    print(f"❌ This script requires Python >= {required}, found {found}.", file=sys.stderr)
    sys.exit(1)

from lib import log, run


def ensure_namespace(ns: str) -> None:
    log.info(f"==> Creating namespace {ns}...")
    manifest = run.run(["kubectl", "create", "namespace", ns, "--dry-run=client", "-o", "yaml"])
    run.run(["kubectl", "apply", "-f", "-"], input_text=manifest)


def deploy_app(ns: str, app_name: str) -> None:
    log.info(f"==> Deploying {app_name} in {ns}...")
    manifest = run.run(
        ["kubectl", "create", "deployment", app_name, "--image=nginx:alpine", "-n", ns, "--dry-run=client", "-o", "yaml"]
    )
    run.run(["kubectl", "apply", "-f", "-"], input_text=manifest)


def expose_clusterip(ns: str, app_name: str) -> None:
    log.info(f"==> Exposing {app_name} as ClusterIP in {ns}...")
    manifest = run.run(
        ["kubectl", "expose", "deployment", app_name, "--port=80", "--target-port=80", "-n", ns, "--dry-run=client", "-o", "yaml"]
    )
    run.run(["kubectl", "apply", "-f", "-"], input_text=manifest)


def apply_yaml(text: str) -> None:
    run.run(["kubectl", "apply", "-f", "-"], input_text=text)


def create_svc_nlb(ns: str) -> None:
    ensure_namespace(ns)
    deploy_app(ns, "demo-nlb-app")

    log.info(f"==> Creating NLB Service in {ns}...")
    apply_yaml(
        f"""\
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
  namespace: {ns}
spec:
  ports:
  - port: 80
  selector:
    app: demo-nlb-app
  type: LoadBalancer
"""
    )


def create_ing_alb(ns: str) -> None:
    ensure_namespace(ns)
    deploy_app(ns, "demo-alb-app")
    expose_clusterip(ns, "demo-alb-app")

    log.info(f"==> Creating ALB Ingress in {ns}...")
    apply_yaml(
        f"""\
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
  name: demo-alb-app
  namespace: {ns}
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
"""
    )


def create_gw_nlb(ns: str) -> None:
    ensure_namespace(ns)
    deploy_app(ns, "demo-gwtcp-app")
    expose_clusterip(ns, "demo-gwtcp-app")

    log.info(f"==> Creating Gateway + TCPRoute (NLB) in {ns}...")
    apply_yaml(
        f"""\
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
  namespace: {ns}
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
  namespace: {ns}
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
  namespace: {ns}
spec:
  scheme: internet-facing
---
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: demo-gwtcp-app-tg-config
  namespace: {ns}
spec:
  targetReference:
    group: ""
    kind: Service
    name: demo-gwtcp-app
  defaultConfiguration:
    targetType: ip
"""
    )


def create_gw_alb(ns: str) -> None:
    ensure_namespace(ns)
    deploy_app(ns, "demo-gwhttp-app")
    expose_clusterip(ns, "demo-gwhttp-app")

    log.info(f"==> Creating Gateway + HTTPRoute (ALB) in {ns}...")
    apply_yaml(
        f"""\
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
  namespace: {ns}
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
  namespace: {ns}
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
  namespace: {ns}
spec:
  scheme: internet-facing
---
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: demo-gwhttp-app-tg-config
  namespace: {ns}
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
"""
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Creates all 4 aws-load-balancer-controller demos, each in its own namespace. "
            "Verify with ../../test_demos.sh afterward."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Optional environment variables (defaults match demos/tf/terraform.tfvars):\n"
            "  SVC_NLB_NAMESPACE   Default: demo-nlb\n"
            "  ING_ALB_NAMESPACE   Default: demo-alb\n"
            "  GW_NLB_NAMESPACE    Default: demo-gwtcp\n"
            "  GW_ALB_NAMESPACE    Default: demo-gwhttp\n"
        ),
    )
    parser.parse_args()

    create_svc_nlb(os.environ.get("SVC_NLB_NAMESPACE", "demo-nlb"))
    create_ing_alb(os.environ.get("ING_ALB_NAMESPACE", "demo-alb"))
    create_gw_nlb(os.environ.get("GW_NLB_NAMESPACE", "demo-gwtcp"))
    create_gw_alb(os.environ.get("GW_ALB_NAMESPACE", "demo-gwhttp"))

    log.info()
    log.info("All demos created. Verify with: ../../test_demos.sh")


if __name__ == "__main__":
    main()
