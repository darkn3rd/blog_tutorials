#!/usr/bin/env python3
"""clean_demos.py — Removes all 4 aws-load-balancer-controller demos created
by deploy_demos.py: deletes the load balancer resources (Service/Ingress/
Gateway+Route), waits for AWS to deprovision the load balancers, then
deletes each demo's namespace, by calling `kubectl` via subprocess.

Requires: kubectl on PATH; Python >= 3.9.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

MIN_PYTHON = (3, 9)
if sys.version_info < MIN_PYTHON:
    found = ".".join(str(p) for p in sys.version_info[:3])
    required = ".".join(str(p) for p in MIN_PYTHON)
    print(f"❌ This script requires Python >= {required}, found {found}.", file=sys.stderr)
    sys.exit(1)

from lib import log, run

# name, namespace, gatewayclass (gatewayclass is cluster-scoped, deleted by
# name - never wholesale, unlike the namespaced kinds below).
DEMOS = [
    ("Service/NLB", "SVC_NLB_NAMESPACE", "demo-nlb", None),
    ("Ingress/ALB", "ING_ALB_NAMESPACE", "demo-alb", None),
    ("Gateway+TCPRoute/NLB", "GW_NLB_NAMESPACE", "demo-gwtcp", "aws-nlb-class"),
    ("Gateway+HTTPRoute/ALB", "GW_ALB_NAMESPACE", "demo-gwhttp", "aws-alb"),
]


def clean_namespace(name: str, ns: str, gatewayclass: str | None) -> None:
    log.info()
    log.info(f"===== Cleaning {name} (namespace: {ns}) =====")

    if not run.run_ok(["kubectl", "get", "namespace", ns]):
        log.info(f"Namespace {ns} not found, skipping.")
        return

    log.info("Deleting namespaced Gateway API resources (if any)...")
    run.run(["kubectl", "delete", "gateway,httproute,tcproute", "--all", "-n", ns, "--ignore-not-found=true"], check=False)
    run.run(["kubectl", "delete", "loadbalancerconfiguration,targetgroupconfiguration", "--all", "-n", ns, "--ignore-not-found=true"], check=False)

    log.info("Deleting Ingress/Service/Deployment...")
    run.run(["kubectl", "delete", "ingress,svc,deployment", "--all", "-n", ns, "--ignore-not-found=true"], check=False)

    log.info("Waiting for load balancer to deprovision...")
    time.sleep(30)

    if gatewayclass:
        log.info(f"Deleting GatewayClass {gatewayclass} (cluster-scoped)...")
        run.run(["kubectl", "delete", "gatewayclass", gatewayclass, "--ignore-not-found=true"], check=False)

    log.info(f"Deleting namespace {ns}...")
    run.run(["kubectl", "delete", "namespace", ns, "--ignore-not-found=true"], check=False)


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

    for name, env_var, default_ns, gatewayclass in DEMOS:
        clean_namespace(name, os.environ.get(env_var, default_ns), gatewayclass)

    log.info()
    log.info("All demo namespaces cleaned up.")


if __name__ == "__main__":
    main()
