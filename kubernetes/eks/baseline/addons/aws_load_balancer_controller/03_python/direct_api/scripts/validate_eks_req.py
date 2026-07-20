#!/usr/bin/env python3
"""validate_eks_req.py — Verify an EKS cluster meets the prerequisites for
installing the AWS Load Balancer Controller.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib import aws
from lib.errors import die
from lib.python_version import verify_python

_counts = {"pass": 0, "fail": 0}


def check_with_detail(label: str, result: str, passed: bool) -> None:
    if passed:
        print(f"  [PASS] {label} — {result}")
        _counts["pass"] += 1
    else:
        print(f"  [FAIL] {label} — {result}")
        _counts["fail"] += 1


def main() -> None:
    verify_python()

    cluster_name = os.environ.get("EKS_CLUSTER_NAME") or die("EKS_CLUSTER_NAME is required")
    region = os.environ.get("EKS_REGION") or die("EKS_REGION is required")
    profile = os.environ.get("AWS_PROFILE") or die("AWS_PROFILE is required")

    aws_clients = aws.AwsClients.create(profile=profile, region=region)

    print(f"==> Validating EKS cluster: {cluster_name} (region: {region})")
    print()

    # ---- OIDC Provider ----
    print("--- OIDC Provider ---")
    try:
        oidc_issuer = aws.get_cluster_oidc_issuer(aws_clients, cluster_name)
    except Exception:  # noqa: BLE001
        oidc_issuer = ""

    if oidc_issuer:
        oidc_id = oidc_issuer.rsplit("/", 1)[-1]
        if aws.oidc_provider_registered_for_issuer(aws_clients, oidc_issuer):
            check_with_detail("OIDC provider registered in IAM", oidc_id, True)
        else:
            check_with_detail(
                "OIDC provider registered in IAM", f"issuer exists but no IAM provider for {oidc_id}", False
            )
    else:
        check_with_detail("OIDC provider registered in IAM", "no OIDC issuer on cluster", False)

    print()

    # ---- EKS Pod Identity Agent ----
    print("--- Pod Identity Addon ---")
    pod_identity_status = aws.addon_status(aws_clients, cluster_name, "eks-pod-identity-agent")
    if pod_identity_status == "ACTIVE":
        check_with_detail("eks-pod-identity-agent addon", "ACTIVE", True)
    else:
        check_with_detail("eks-pod-identity-agent addon", pod_identity_status or "not installed", False)

    print()

    # ---- VPC CNI Addon ----
    print("--- VPC CNI Addon ---")
    vpc_cni_status = aws.addon_status(aws_clients, cluster_name, "vpc-cni")
    if vpc_cni_status == "ACTIVE":
        check_with_detail("vpc-cni addon", "ACTIVE", True)
    else:
        check_with_detail("vpc-cni addon", vpc_cni_status or "not installed", False)

    # Check VPC CNI uses IRSA or Pod Identity (not node-level)
    vpc_cni_sa_role = aws.addon_service_account_role_arn(aws_clients, cluster_name, "vpc-cni")
    vpc_cni_pod_identity = aws.find_pod_identity_association_id(
        aws_clients, cluster_name, "kube-system", "aws-node"
    )

    if vpc_cni_pod_identity:
        check_with_detail("vpc-cni auth", f"Pod Identity association: {vpc_cni_pod_identity}", True)
    elif vpc_cni_sa_role:
        check_with_detail("vpc-cni auth", f"IRSA role: {vpc_cni_sa_role.rsplit('/', 1)[-1]}", True)
    else:
        check_with_detail("vpc-cni auth", "no IRSA or Pod Identity configured (likely using node-level privileges)", False)

    print()

    # ---- Subnet Tagging ----
    print("--- Subnet Tagging ---")
    vpc_id = aws.get_cluster_vpc_id(aws_clients, cluster_name)
    subnets = aws.describe_subnets(aws_clients, vpc_id)

    def tagged_count(role_key: str) -> int:
        count = 0
        for subnet in subnets:
            tags = {t["Key"]: t["Value"] for t in subnet.get("Tags", [])}
            if tags.get(role_key) == "1":
                count += 1
        return count

    public_tagged = tagged_count("kubernetes.io/role/elb")
    if public_tagged > 0:
        check_with_detail("Public subnets tagged (kubernetes.io/role/elb=1)", f"{public_tagged} subnet(s)", True)
    else:
        check_with_detail("Public subnets tagged (kubernetes.io/role/elb=1)", "none found", False)

    private_tagged = tagged_count("kubernetes.io/role/internal-elb")
    if private_tagged > 0:
        check_with_detail(
            "Private subnets tagged (kubernetes.io/role/internal-elb=1)", f"{private_tagged} subnet(s)", True
        )
    else:
        check_with_detail("Private subnets tagged (kubernetes.io/role/internal-elb=1)", "none found", False)

    print()

    # ---- Summary ----
    total = _counts["pass"] + _counts["fail"]
    print(f"==> Results: {_counts['pass']}/{total} passed")
    if _counts["fail"] > 0:
        print(f"    {_counts['fail']} check(s) failed — resolve before installing AWS Load Balancer Controller.")
        sys.exit(1)
    print("    Cluster is ready for AWS Load Balancer Controller.")


if __name__ == "__main__":
    main()
