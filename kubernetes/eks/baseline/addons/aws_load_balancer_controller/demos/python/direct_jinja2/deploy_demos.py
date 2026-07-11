#!/usr/bin/env python3
"""deploy_demos.py — Creates all 4 aws-load-balancer-controller demos, each in
its own namespace, using the kubernetes client:
  - Service/NLB            (namespace: $SVC_NLB_NAMESPACE)
  - Ingress/ALB             (namespace: $ING_ALB_NAMESPACE)
  - Gateway+TCPRoute/NLB    (namespace: $GW_NLB_NAMESPACE)
  - Gateway+HTTPRoute/ALB   (namespace: $GW_ALB_NAMESPACE)

Every manifest is a Jinja2 template under templates/, rendered to YAML text,
parsed to a dict, and passed as the `body=` argument to the matching typed
client method (create_namespaced_deployment, create_namespaced_service,
...). Custom resources (Gateway, TCPRoute, ...) have no typed method to
call, so those fall back to the DynamicClient's generic apply.

Verify with ../../test_demos.sh afterward.

Works against a cluster with the AWS Load Balancer Controller installed,
however that install happened.

Requires: kubernetes >= 29.0, PyYAML >= 6.0, Jinja2 >= 3.1 (see requirements.txt); Python >= 3.9.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

MIN_PYTHON = (3, 9)
if sys.version_info < MIN_PYTHON:
    found = ".".join(str(p) for p in sys.version_info[:3])
    required = ".".join(str(p) for p in MIN_PYTHON)
    print(f"❌ This script requires Python >= {required}, found {found}.", file=sys.stderr)
    sys.exit(1)

import yaml
from jinja2 import Environment, FileSystemLoader
from kubernetes import client, config, dynamic
from kubernetes.client import ApiException

TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"
JINJA_ENV = Environment(loader=FileSystemLoader(str(TEMPLATES_DIR)), keep_trailing_newline=True)


def log(message: str = "") -> None:
    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}] {message}")


def render(template_name: str, **variables: str) -> str:
    return JINJA_ENV.get_template(template_name).render(**variables)


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


def apply_template(
    core_v1: client.CoreV1Api,
    apps_v1: client.AppsV1Api,
    networking_v1: client.NetworkingV1Api,
    dyn: dynamic.DynamicClient,
    template_name: str,
    **variables: str,
) -> None:
    text = render(template_name, **variables)
    for doc in yaml.safe_load_all(text):
        if doc:
            apply_manifest(core_v1, apps_v1, networking_v1, dyn, doc)


def ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    log(f"==> Creating namespace {ns}...")
    apply_template(core_v1, apps_v1, networking_v1, dyn, "namespace.yaml.j2", ns=ns)


def deploy_app(core_v1, apps_v1, networking_v1, dyn, ns: str, app_name: str) -> None:
    log(f"==> Deploying {app_name} in {ns}...")
    apply_template(core_v1, apps_v1, networking_v1, dyn, "deployment.yaml.j2", ns=ns, app_name=app_name)


def expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns: str, app_name: str) -> None:
    log(f"==> Exposing {app_name} as ClusterIP in {ns}...")
    apply_template(core_v1, apps_v1, networking_v1, dyn, "service_clusterip.yaml.j2", ns=ns, app_name=app_name)


def create_svc_nlb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-nlb-app")

    log(f"==> Creating NLB Service in {ns}...")
    apply_template(core_v1, apps_v1, networking_v1, dyn, "service_nlb.yaml.j2", ns=ns, app_name="demo-nlb-app")


def create_ing_alb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-alb-app")
    expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns, "demo-alb-app")

    log(f"==> Creating ALB Ingress in {ns}...")
    apply_template(core_v1, apps_v1, networking_v1, dyn, "ingress_alb.yaml.j2", ns=ns, app_name="demo-alb-app")


def create_gw_nlb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwtcp-app")
    expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwtcp-app")

    log(f"==> Creating Gateway + TCPRoute (NLB) in {ns}...")
    apply_template(core_v1, apps_v1, networking_v1, dyn, "gateway_nlb.yaml.j2", ns=ns, app_name="demo-gwtcp-app")


def create_gw_alb(core_v1, apps_v1, networking_v1, dyn, ns: str) -> None:
    ensure_namespace(core_v1, apps_v1, networking_v1, dyn, ns)
    deploy_app(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwhttp-app")
    expose_clusterip(core_v1, apps_v1, networking_v1, dyn, ns, "demo-gwhttp-app")

    log(f"==> Creating Gateway + HTTPRoute (ALB) in {ns}...")
    apply_template(core_v1, apps_v1, networking_v1, dyn, "gateway_alb.yaml.j2", ns=ns, app_name="demo-gwhttp-app")


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
