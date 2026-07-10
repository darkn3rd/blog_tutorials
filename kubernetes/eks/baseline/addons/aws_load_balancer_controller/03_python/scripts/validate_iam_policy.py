#!/usr/bin/env python3
"""validate_iam_policy.py — Verify the AWS Load Balancer Controller IAM
policy contains every required statement.

If --policy-name is omitted, the policy is discovered instead: found via
whichever role is bound to the controller's ServiceAccount (IRSA annotation
or Pod Identity association), then whichever single policy is attached to
that role, regardless of what either is named.

Exit codes:
  0  Policy is present and all required statements are satisfied.
  1  Policy is missing, inaccessible, or one or more statements fail.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib import aws, k8s, role_discovery
from lib.errors import die
from lib.policy_validation import validate_policy
from lib.python_version import verify_python


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(
        description="Verify the AWS Load Balancer Controller IAM policy contains every required statement."
    )
    parser.add_argument("-p", "--policy-name", default="", help="IAM policy name to validate. If omitted, discovered instead.")
    parser.add_argument("-a", "--account-id", default="", help="AWS account ID (default: resolved via STS)")
    parser.add_argument(
        "-c", "--cluster-name", default=os.environ.get("EKS_CLUSTER_NAME", ""),
        help="EKS cluster name, needed for discovery's Pod Identity lookup (default: $EKS_CLUSTER_NAME)",
    )
    parser.add_argument(
        "-r", "--region", default=os.environ.get("EKS_REGION", ""),
        help="AWS region the cluster lives in, needed for discovery's Pod Identity lookup - it's a "
        "region-scoped API call, so the wrong region (or none) silently finds nothing instead of "
        "erroring (default: $EKS_REGION)",
    )
    parser.add_argument("-n", "--namespace", default="kube-system", help="ServiceAccount's namespace, for discovery")
    parser.add_argument(
        "-s", "--service-account", default="aws-load-balancer-controller",
        help="ServiceAccount name, for discovery",
    )
    args = parser.parse_args()

    # IAM is a global service - the region below only matters for the
    # optional Pod Identity discovery path (EKS is regional), and that path
    # already requires --region/--cluster-name to be set before it runs.
    profile = os.environ.get("AWS_PROFILE", "")
    aws_clients = aws.AwsClients.create(profile=profile, region=args.region)

    aws.verify_aws_connectivity(aws_clients)

    account_id = args.account_id
    if not account_id:
        print("Resolving AWS account ID...")
        account_id = aws.get_account_id(aws_clients)

    if args.policy_name:
        policy_arn = f"arn:aws:iam::{account_id}:policy/{args.policy_name}"
    else:
        if not args.cluster_name:
            die(
                "No --policy-name given, so the role/policy must be discovered -- pass --cluster-name "
                "(or set $EKS_CLUSTER_NAME) so a Pod Identity association can be looked up if there's "
                "no IRSA annotation."
            )
        if not args.region:
            die(
                "No --policy-name given, so the role/policy must be discovered -- pass --region (or set "
                "$EKS_REGION), since the Pod Identity lookup is region-scoped."
            )

        k8s_client = k8s.K8sClient.create()
        k8s.verify_k8s_connectivity(k8s_client)

        print(f"No --policy-name given -- discovering the role and policy from the '{args.service_account}' ServiceAccount...")
        role_arn = role_discovery.find_role_arn(
            aws_clients, k8s_client, args.cluster_name, args.namespace, args.service_account
        )
        role_name = role_arn.rsplit("/", 1)[-1]
        print(f"  Role   : {role_name}")

        policy_arn = role_discovery.find_attached_policy_arn(aws_clients, role_name)
        print(f"  Policy : {policy_arn.rsplit('/', 1)[-1]}")

    print()
    print("─" * 62)
    print("  IAM Policy Validation")
    print(f"  {policy_arn}")
    print("─" * 62)

    if not validate_policy(aws_clients, policy_arn):
        sys.exit(1)


if __name__ == "__main__":
    main()
