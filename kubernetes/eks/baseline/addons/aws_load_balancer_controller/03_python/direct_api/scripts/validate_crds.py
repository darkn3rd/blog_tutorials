#!/usr/bin/env python3
"""validate_crds.py — Verify Gateway API CRDs are installed in the cluster.

Usage:
  validate_crds.py --channel <standard|experimental> --source <gateway-api|aws-gateway|all>

Exit codes:
  0  All expected CRDs are present.
  1  One or more CRDs are missing, or a usage/connectivity error occurred.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib import crd_lists, k8s
from lib.python_version import verify_python


def validate_group(heading: str, installed: set[str], crds: list[str]) -> int:
    """Prints a headed section for one CRD group. Returns the number missing."""
    print()
    print(f"  {heading}")
    print(f"  {'─' * len(heading)}")

    missing = 0
    for crd in crds:
        if crd in installed:
            print(f"  ✅  {crd}")
        else:
            print(f"  ❌  {crd}")
            missing += 1
    return missing


def validate_crds(k8s_client: k8s.K8sClient, channel: str, source: str) -> bool:
    installed = k8s.fetch_installed_crds(k8s_client)

    print("─" * 62)
    print("  CRD Validation")
    print("─" * 62)

    total_expected = 0
    total_missing = 0

    def gateway_group() -> tuple[str, list[str]]:
        if channel == "experimental":
            return "Gateway API  (experimental channel)", crd_lists.EXPERIMENTAL_GATEWAY_CRDS
        return "Gateway API  (standard channel)", crd_lists.STANDARD_GATEWAY_CRDS

    if source in ("gateway-api", "all"):
        heading, crds = gateway_group()
        total_missing += validate_group(heading, installed, crds)
        total_expected += len(crds)
    if source in ("aws-gateway", "all"):
        total_missing += validate_group("AWS Gateway", installed, crd_lists.AWS_GATEWAY_CRDS)
        total_expected += len(crd_lists.AWS_GATEWAY_CRDS)

    print()
    print("─" * 62)

    total_found = total_expected - total_missing
    if total_missing == 0:
        print(f"  ✅  All {total_expected} CRDs present.")
        return True

    print(f"  ❌  {total_found} of {total_expected} CRDs present  ({total_missing} missing).", file=sys.stderr)
    return False


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(description="Verify Gateway API CRDs are installed in the cluster.")
    parser.add_argument(
        "-c", "--channel", default="experimental", choices=["standard", "experimental"],
        help="Channel of the Gateway API manifests used during install. Default: experimental",
    )
    parser.add_argument(
        "-s", "--source", default="all", choices=["gateway-api", "aws-gateway", "all"],
        help="Which CRD group(s) to validate. Default: all",
    )
    args = parser.parse_args()

    k8s_client = k8s.K8sClient.create()
    k8s.verify_k8s_connectivity(k8s_client)

    if not validate_crds(k8s_client, args.channel, args.source):
        sys.exit(1)


if __name__ == "__main__":
    main()
