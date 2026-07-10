#!/usr/bin/env python3
"""validate_auth.py — Verify the full IAM auth chain for the AWS Load
Balancer Controller, whichever mechanism actually binds it:

  ServiceAccount -> IRSA annotation or Pod Identity association
  -> IAM role exists -> policy attached -> policy contents correct

Exit codes:
  0  All auth chain checks passed.
  1  One or more checks failed.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib import aws, k8s
from lib.policy_validation import validate_policy
from lib.python_version import verify_python


def step(num: int, desc: str) -> None:
    print()
    print(f"  Step {num}  ·  {desc}")
    print(f"  {'─' * (len(desc) + 10)}")


def ok(message: str) -> None:
    print(f"  ✅  {message}")


def fail(message: str) -> None:
    print(f"  ❌  {message}", file=sys.stderr)
    sys.exit(1)


def validate_auth(
    aws_clients: aws.AwsClients,
    k8s_client: k8s.K8sClient,
    sa_name: str,
    namespace: str,
    cluster_name: str,
    region: str,
    expected_policy_name: str,
) -> None:
    print("═" * 62)
    print("  IAM Auth Chain Validation")
    print("═" * 62)

    # ── Step 1: ServiceAccount exists ──────────────────────────────────
    step(1, "ServiceAccount exists")
    print(f"  Namespace : {namespace}")
    print(f"  Name      : {sa_name}")

    if k8s.service_account_exists(k8s_client, sa_name, namespace):
        ok(f"ServiceAccount '{sa_name}' found in namespace '{namespace}'.")
    else:
        fail(f"ServiceAccount '{sa_name}' not found in namespace '{namespace}'.")

    # ── Step 2: bound to an IAM role via IRSA or Pod Identity ──────────
    step(2, "Bound to an IAM role (IRSA or Pod Identity)")

    role_arn = k8s.get_service_account_annotation(k8s_client, sa_name, namespace, "eks.amazonaws.com/role-arn")
    auth_mode = ""

    if role_arn:
        auth_mode = "IRSA"
        ok("IRSA role-arn annotation present.")
    elif cluster_name and region:
        role_arn = aws.get_pod_identity_role_arn(aws_clients, cluster_name, namespace, sa_name)
        if role_arn:
            auth_mode = "Pod Identity"
            ok("Pod Identity association found.")

    if not role_arn:
        if not cluster_name or not region:
            fail(
                f"No IRSA role-arn annotation on '{sa_name}', and --cluster-name/--region (or "
                "$EKS_CLUSTER_NAME/$EKS_REGION) weren't given, so a Pod Identity association "
                "couldn't be looked up either."
            )
        else:
            fail(
                f"ServiceAccount '{sa_name}' is bound to a role via neither an IRSA role-arn "
                f"annotation nor an EKS Pod Identity association in region '{region}'."
            )

    print(f"  Auth mode : {auth_mode}")
    print(f"  Role ARN  : {role_arn}")

    role_name = role_arn.rsplit("/", 1)[-1]
    print(f"  Role Name : {role_name}")

    # ── Step 3: IAM role exists ─────────────────────────────────────────
    step(3, "IAM role exists")
    if aws.role_exists(aws_clients, role_name):
        ok(f"IAM role '{role_name}' exists.")
    else:
        fail(f"IAM role '{role_name}' does not exist (or is not accessible).")

    # ── Step 4: policy is attached to the role ──────────────────────────
    step(4, "Policy attached to role")

    matched_policy_arn = ""

    if expected_policy_name:
        print(f"  Looking for : {expected_policy_name}")
        attached = aws.get_role_attached_policy_arns(aws_clients, role_name)
        for arn in attached:
            if arn.rsplit("/", 1)[-1] == expected_policy_name:
                matched_policy_arn = arn
                break

        if not matched_policy_arn:
            print(f"  Attached policies on role '{role_name}':")
            if not attached:
                print("    (none)")
            else:
                for arn in attached:
                    print(f"    • {arn}")
            fail(f"Policy '{expected_policy_name}' is not attached to role '{role_name}'.")
    else:
        print("  No --policy-name given -- discovering whichever policy is attached...")
        from lib.role_discovery import find_attached_policy_arn

        matched_policy_arn = find_attached_policy_arn(aws_clients, role_name)

    ok("Policy is attached.")
    print(f"  Policy ARN  : {matched_policy_arn}")

    # ── Step 5: policy document is correct ───────────────────────────────
    step(5, "Policy document contents")
    print()
    print("─" * 62)
    print("  IAM Policy Validation")
    print(f"  {matched_policy_arn}")
    print("─" * 62)

    if not validate_policy(aws_clients, matched_policy_arn):
        sys.exit(1)

    print()
    print("═" * 62)
    print(f"  ✅  All auth chain checks passed ({auth_mode}).")
    print("═" * 62)


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(description="Verify the full IAM auth chain for the AWS Load Balancer Controller.")
    parser.add_argument("-s", "--service-account", default="aws-load-balancer-controller")
    parser.add_argument("-n", "--namespace", default="kube-system")
    parser.add_argument("-c", "--cluster-name", default=os.environ.get("EKS_CLUSTER_NAME", ""))
    parser.add_argument("-r", "--region", default=os.environ.get("EKS_REGION", ""))
    parser.add_argument("-p", "--policy-name", default="")
    args = parser.parse_args()

    profile = os.environ.get("AWS_PROFILE", "")
    aws_clients = aws.AwsClients.create(profile=profile, region=args.region)
    k8s_client = k8s.K8sClient.create()

    aws.verify_aws_connectivity(aws_clients)
    k8s.verify_k8s_connectivity(k8s_client)

    validate_auth(
        aws_clients, k8s_client, args.service_account, args.namespace, args.cluster_name, args.region, args.policy_name
    )


if __name__ == "__main__":
    main()
