#!/usr/bin/env python3
"""deploy_demos.py — Creates all 4 aws-load-balancer-controller demos, each in
its own namespace, using the kubernetes client:
  - Service/NLB            (namespace: $SVC_NLB_NAMESPACE)
  - Ingress/ALB             (namespace: $ING_ALB_NAMESPACE)
  - Gateway+TCPRoute/NLB    (namespace: $GW_NLB_NAMESPACE)
  - Gateway+HTTPRoute/ALB   (namespace: $GW_ALB_NAMESPACE)

Every manifest here - including the plain Namespace/Deployment/Service ones -
is written as a multiline f-string of YAML, parsed to a dict, and passed as
the `body=` argument to the matching typed client method
(create_namespaced_deployment, create_namespaced_service, ...). Custom
resources (Gateway, TCPRoute, ...) have no typed method to call, so those
fall back to the DynamicClient's generic apply.

Verify with ../../test_demos.sh afterward.

Works against a cluster with the AWS Load Balancer Controller installed,
however that install happened.

Requires: kubernetes >= 29.0, PyYAML >= 6.0 (see requirements.txt); Python >= 3.9.
"""

from __future__ import annotations

import argparse
import os
import sys
import time

MIN_PYTHON = (3, 9)
if sys.version_info < MIN_PYTHON:
    found = ".".join(str(p) for p in sys.version_info[:3])
    required = ".".join(str(p) for p in MIN_PYTHON)
    print(f"❌ This script requires Python >= {required}, found {found}.", file=sys.stderr)
    sys.exit(1)

import yaml
from kubernetes import client, config, dynamic
from kubernetes.client import ApiException


def log(message: str = "") -> None:
    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}] {message}")


def apply_manifest(
    core_v1: client.CoreV1Api,
    apps_v1: client.AppsV1Api,
    networking_v1: client.NetworkingV1Api,
    dyn: dynamic.DynamicClient,
    doc: dict,
) -> None:
    """Dispatches one parsed YAML document to the matching typed client
    call, creating it or replacing the existing one on a 409 Conflict.
    Anything that isn't a built-in kind (Gateway API objects, LBC config
    objects) falls back to the DynamicClient, since there's no
    create_namespaced_<kind>() method to call for a custom resource.
    """
    kind = doc["kind"]
    name = doc["metadata"]["name"]
    ns = doc["metadata"].get("namespace")

    if kind == "Namespace":
        try:
            core_v1.create_namespace(body=doc)
        except ApiException as exc:
            if exc.status != 409:
                raise
    elif kind == "Deployment":
        try:
            apps_v1.create_namespaced_deployment(namespace=ns, body=doc)
        except ApiException as exc:
            if exc.status == 409:
                apps_v1.replace_namespaced_deployment(name, ns, doc)
            else:
                raise
    elif kind == "Service":
        try:
            core_v1.create_namespaced_service(namespace=ns, body=doc)
        except ApiException as exc:
            if exc.status == 409:
                existing = core_v1.read_namespaced_service(name, ns)
                doc["metadata"]["resourceVersion"] = existing.metadata.resource_version
                doc.setdefault("spec", {})["clusterIP"] = existing.spec.cluster_ip
                core_v1.replace_namespaced_service(name, ns, doc)
            else:
                raise
    elif kind == "Ingress":
        try:
            networking_v1.create_namespaced_ingress(namespace=ns, body=doc)
        except ApiException as exc:
            if exc.status == 409:
                networking_v1.replace_namespaced_ingress(name, ns, doc)
            else:
                raise
    else:
        resource = dyn.resources.get(api_version=doc["apiVersion"], kind=kind)
        resource.server_side_apply(
            body=doc, name=name, namespace=ns,
            field_manager="aws-load-balancer-controller-demos", force_conflicts=True,
        )


def apply_yaml(
    core_v1: client.CoreV1Api,
    apps_v1: client.AppsV1Api,
    networking_v1: client.NetworkingV1Api,
    dyn: dynamic.DynamicClient,
    text: str,
) -> None:
    for doc in yaml.safe_load_all(text):
        if doc:
            apply_manifest(core_v1, apps_v1, networking_v1, dyn, doc)


def ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    log(f"==> Creating namespace {ns}...")
    apply_yaml(
        core_v1, apps_v1, networking_v1, dyn,
        f"""\
apiVersion: v1
kind: Namespace
metadata:
  name: {ns}
""",
    )


def deploy_app(core_v1, apps_v1, networking_v1, dyn, ns: str, app_name: str) -> None:
    log(f"==> Deploying {app_name} in {ns}...")
    apply_yaml(
        core_v1, apps_v1, networking_v1, dyn,
        f"""\
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {app_name}
  namespace: {ns}
  labels:
    app: {app_name}
spec:
  selector:
    matchLabels:
      app: {app_name}
  template:
    metadata:
      labels:
        app: {app_name}
    spec:
      containers:
        - name: {app_name}
          image: nginx:alpine
""",
    )


def expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns: str, app_name: str) -> None:
    log(f"==> Exposing {app_name} as ClusterIP in {ns}...")
    apply_yaml(
        core_v1, apps_v1, networking_v1, dyn,
        f"""\
apiVersion: v1
kind: Service
metadata:
  name: {app_name}
  namespace: {ns}
spec:
  selector:
    app: {app_name}
  ports:
    - port: 80
      targetPort: 80
""",
    )


def create_svc_nlb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-nlb-app")

    log(f"==> Creating NLB Service in {ns}...")
    apply_yaml(
        core_v1, apps_v1, networking_v1, dyn,
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
""",
    )


def create_ing_alb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-alb-app")
    expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns, "demo-alb-app")

    log(f"==> Creating ALB Ingress in {ns}...")
    apply_yaml(
        core_v1, apps_v1, networking_v1, dyn,
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
""",
    )


def create_gw_nlb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwtcp-app")
    expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwtcp-app")

    log(f"==> Creating Gateway + TCPRoute (NLB) in {ns}...")
    apply_yaml(
        core_v1, apps_v1, networking_v1, dyn,
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
""",
    )


def create_gw_alb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwhttp-app")
    expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwhttp-app")

    log(f"==> Creating Gateway + HTTPRoute (ALB) in {ns}...")
    apply_yaml(
        core_v1, apps_v1, networking_v1, dyn,
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
""",
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

    svc_nlb_ns = os.environ.get("SVC_NLB_NAMESPACE", "demo-nlb")
    ing_alb_ns = os.environ.get("ING_ALB_NAMESPACE", "demo-alb")
    gw_nlb_ns = os.environ.get("GW_NLB_NAMESPACE", "demo-gwtcp")
    gw_alb_ns = os.environ.get("GW_ALB_NAMESPACE", "demo-gwhttp")

    config.load_kube_config()
    api_client = client.ApiClient()
    core_v1 = client.CoreV1Api(api_client)
    apps_v1 = client.AppsV1Api(api_client)
    networking_v1 = client.NetworkingV1Api(api_client)
    dyn = dynamic.DynamicClient(api_client)

    create_svc_nlb(core_v1, apps_v1, networking_v1, dyn, svc_nlb_ns)
    create_ing_alb(core_v1, apps_v1, networking_v1, dyn, ing_alb_ns)
    create_gw_nlb(core_v1, apps_v1, networking_v1, dyn, gw_nlb_ns)
    create_gw_alb(core_v1, apps_v1, networking_v1, dyn, gw_alb_ns)

    log()
    log("All demos created. Verify with: ../../test_demos.sh")


if __name__ == "__main__":
    main()
