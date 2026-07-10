#!/usr/bin/env python3
"""delete_crds.py — Remove Gateway API CRDs from the cluster. Python port of
../../01_cli/scripts/delete_crds.sh.

WARNING: Deleting CRDs removes all custom resources of those types
cluster-wide. This operation is irreversible without a backup.

Exit codes:
  0  All targeted CRDs were deleted (or were already absent).
  1  One or more deletes failed, or a usage/connectivity error occurred.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from kubernetes.client import ApiException

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib import crd_lists, k8s
from lib.errors import die
from lib.python_version import verify_python


def confirm_deletion(crds: list[str]) -> None:
    print()
    print(f"⚠️  The following {len(crds)} CRD(s) will be permanently deleted:")
    print("    (All custom resources of these types will be removed cluster-wide.)")
    print()
    for crd in crds:
        print(f"    🗑️  {crd}")
    print()
    answer = input("Type 'yes' to confirm: ")
    if answer != "yes":
        print("Aborted. No changes were made.")
        sys.exit(0)


def delete_crds(k8s_client: k8s.K8sClient, channel: str, source: str, dry_run: bool, skip_confirm: bool) -> bool:
    try:
        expected = crd_lists.resolve_crds(channel, source)
    except ValueError as exc:
        die(str(exc))

    installed = k8s.fetch_installed_crds(k8s_client)

    targets = [crd for crd in expected if crd in installed]
    absent = [crd for crd in expected if crd not in installed]

    if not targets:
        print("✅ Nothing to delete — none of the expected CRDs are installed.")
        return True

    if dry_run:
        print("ℹ️  Dry-run mode — no changes will be made.")
    elif not skip_confirm:
        confirm_deletion(targets)

    print()
    print(f"Deleting CRDs  [channel: {channel}]  [source: {source}]")
    print("─" * 62)

    deleted: list[str] = []
    failed: list[str] = []
    for crd in targets:
        try:
            if not dry_run:
                k8s_client.apiextensions_v1.delete_custom_resource_definition(crd)
            print(f"  🗑️  {crd} — deleted")
            deleted.append(crd)
        except ApiException as exc:
            print(f"  ❌ {crd} — delete failed: {exc.reason}", file=sys.stderr)
            failed.append(crd)

    for crd in absent:
        print(f"  ⚠️  {crd} — not found, skipped")

    print("─" * 62)

    dry_run_label = " (dry-run)" if dry_run else ""
    print(f"Summary{dry_run_label}: {len(deleted)} deleted, {len(absent)} skipped, {len(failed)} failed.")

    return not failed


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(description="Remove Gateway API CRDs from the cluster.")
    parser.add_argument("-c", "--channel", default="experimental", choices=["standard", "experimental"])
    parser.add_argument("-s", "--source", default="all", choices=["gateway-api", "aws-gateway", "all"])
    parser.add_argument("-y", "--yes", action="store_true", help="Skip the confirmation prompt and delete immediately.")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be deleted without making any changes.")
    args = parser.parse_args()

    k8s_client = k8s.K8sClient.create()
    k8s.verify_k8s_connectivity(k8s_client)

    if not delete_crds(k8s_client, args.channel, args.source, args.dry_run, args.yes):
        sys.exit(1)


if __name__ == "__main__":
    main()
