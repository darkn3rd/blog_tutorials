#!/usr/bin/env python3
"""clean_demos.py — Removes all 4 aws-load-balancer-controller demos created
by deploy_demos.py: deletes the load balancer resources (Service/Ingress/
Gateway+Route), waits for AWS to deprovision the load balancers, then
deletes each demo's namespace. Python port of demos/cli/clean_demos.sh,
using the kubernetes client directly instead of shelling out to kubectl.

Self-contained on purpose - see deploy_demos.py's docstring.

Requires: kubernetes >= 29.0 (see requirements.txt); Python >= 3.9.
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

from kubernetes import client, config, dynamic
from kubernetes.client import ApiException
from kubernetes.dynamic.exceptions import NotFoundError, ResourceNotFoundError

# name, namespace, gatewayclass (gatewayclass is cluster-scoped, deleted by
# name - never wholesale, unlike the namespaced kinds below).
DEMOS = [
    ("Service/NLB", "SVC_NLB_NAMESPACE", "demo-nlb", None),
    ("Ingress/ALB", "ING_ALB_NAMESPACE", "demo-alb", None),
    ("Gateway+TCPRoute/NLB", "GW_NLB_NAMESPACE", "demo-gwtcp", "aws-nlb-class"),
    ("Gateway+HTTPRoute/ALB", "GW_ALB_NAMESPACE", "demo-gwhttp", "aws-alb"),
]

# Namespaced Gateway API / LBC-config kinds this cleans up wholesale within
# each demo's namespace - mirrors clean_demos.sh's
# `kubectl delete gateway,httproute,tcproute --all -n "$ns"` and the
# LoadBalancerConfiguration/TargetGroupConfiguration line right after it.
GATEWAY_KINDS = ["Gateway", "HTTPRoute", "TCPRoute"]
LBC_CONFIG_KINDS = ["LoadBalancerConfiguration", "TargetGroupConfiguration"]


def log(message: str = "") -> None:
    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}] {message}")


def namespace_exists(core_v1: client.CoreV1Api, ns: str) -> bool:
    try:
        core_v1.read_namespace(ns)
        return True
    except ApiException as exc:
        if exc.status == 404:
            return False
        raise


def delete_all_of_kind_in_namespace(dyn: dynamic.DynamicClient, kind: str, ns: str) -> None:
    """Deletes every live instance of `kind` in one namespace. Silently
    no-ops if the kind's CRD isn't installed - mirrors clean_demos.sh's
    `2>/dev/null || true` on these same calls.
    """
    try:
        resource = dyn.resources.get(kind=kind)
    except (ResourceNotFoundError, NotFoundError):
        return

    try:
        items = resource.get(namespace=ns).items
    except (ApiException, NotFoundError):
        return

    for item in items:
        try:
            resource.delete(name=item.metadata.name, namespace=ns)
        except (ApiException, NotFoundError):
            pass


def delete_gatewayclass(dyn: dynamic.DynamicClient, name: str) -> None:
    try:
        resource = dyn.resources.get(kind="GatewayClass")
        resource.delete(name=name)
    except (ApiException, NotFoundError, ResourceNotFoundError):
        pass


def clean_namespace(
    core_v1: client.CoreV1Api,
    networking_v1: client.NetworkingV1Api,
    apps_v1: client.AppsV1Api,
    dyn: dynamic.DynamicClient,
    name: str,
    ns: str,
    gatewayclass: str | None,
) -> None:
    log()
    log(f"===== Cleaning {name} (namespace: {ns}) =====")

    if not namespace_exists(core_v1, ns):
        log(f"Namespace {ns} not found, skipping.")
        return

    log("Deleting namespaced Gateway API resources (if any)...")
    for kind in GATEWAY_KINDS:
        delete_all_of_kind_in_namespace(dyn, kind, ns)
    for kind in LBC_CONFIG_KINDS:
        delete_all_of_kind_in_namespace(dyn, kind, ns)

    log("Deleting Ingress/Service/Deployment...")
    try:
        networking_v1.delete_collection_namespaced_ingress(ns)
    except ApiException:
        pass
    try:
        for svc in core_v1.list_namespaced_service(ns).items:
            core_v1.delete_namespaced_service(svc.metadata.name, ns)
    except ApiException:
        pass
    try:
        apps_v1.delete_collection_namespaced_deployment(ns)
    except ApiException:
        pass

    log("Waiting for load balancer to deprovision...")
    time.sleep(30)

    if gatewayclass:
        log(f"Deleting GatewayClass {gatewayclass} (cluster-scoped)...")
        delete_gatewayclass(dyn, gatewayclass)

    log(f"Deleting namespace {ns}...")
    try:
        core_v1.delete_namespace(ns)
    except ApiException as exc:
        if exc.status != 404:
            raise


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Removes all 4 aws-load-balancer-controller demos created by deploy_demos.py: "
            "deletes the load balancer resources (Service/Ingress/Gateway+Route), waits for "
            "AWS to deprovision the load balancers, then deletes each demo's namespace."
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

    config.load_kube_config()
    api_client = client.ApiClient()
    core_v1 = client.CoreV1Api(api_client)
    networking_v1 = client.NetworkingV1Api(api_client)
    apps_v1 = client.AppsV1Api(api_client)
    dyn = dynamic.DynamicClient(api_client)

    for name, env_var, default_ns, gatewayclass in DEMOS:
        ns = os.environ.get(env_var, default_ns)
        clean_namespace(core_v1, networking_v1, apps_v1, dyn, name, ns, gatewayclass)

    log()
    log("All demo namespaces cleaned up.")


if __name__ == "__main__":
    main()
