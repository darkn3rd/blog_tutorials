#!/usr/bin/env python3
"""install_aws_lbc.py — Installs the AWS Load Balancer Controller onto an
existing EKS cluster, using boto3 and the kubernetes client instead of
shelling out to `aws`/`kubectl`/`eksctl`. Since boto3 talks to the IAM/EKS
APIs directly, provisioning the IAM binding is always done the same way
regardless of tooling - this script only takes an auth mode.

Usage:
  install_aws_lbc.py [auth]

Arguments:
  auth   Authentication mechanism: irsa or pod-identity. Default: irsa

Options:
  -h, --help   Show this help message and exit

Required environment variables:
  EKS_CLUSTER_NAME   Name of the target EKS cluster
  EKS_REGION         AWS region the cluster is in
  AWS_PROFILE        AWS CLI profile to use

Examples:
  EKS_CLUSTER_NAME=my-cluster EKS_REGION=us-east-2 AWS_PROFILE=default ./install_aws_lbc.py
  EKS_CLUSTER_NAME=my-cluster EKS_REGION=us-east-2 AWS_PROFILE=default ./install_aws_lbc.py pod-identity
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import aws, helm, k8s, log, naming
from lib.errors import die
from lib.python_version import verify_python

HELM_CHART_VERSION = "3.4.0"
# Not cluster-scoped: unlike the IAM role/policy (see lib/naming.py), a
# ServiceAccount already lives in one specific cluster's own API server -
# there's no account-wide namespace for two clusters' ServiceAccounts to
# collide in, so it keeps the name the Helm chart expects by default.
SERVICE_ACCOUNT_NAME = "aws-load-balancer-controller"
SA_NAMESPACE = "kube-system"


def verify_requirements(aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient) -> None:
    log.info("Checking Kubernetes cluster connection...")
    k8s.verify_k8s_connectivity(k8s_client)
    log.ok(f"Cluster connection verified: {k8s.current_context()}")

    log.info("Checking AWS connectivity and credentials...")
    caller_arn = aws.verify_aws_connectivity(aws_clients)
    log.ok(f"AWS connection verified: {caller_arn}")


def create_lbc_iam_policy(aws_clients: aws.AwsClients, policy_name: str, policy_arn: str, cluster_name: str) -> None:
    log.info("Checking for existing LBC IAM Policy...")
    if aws.policy_exists(aws_clients, policy_arn):
        log.ok("IAM Policy already exists. Skipping creation.")
        return

    log.info("Creating LBC IAM Policy (Injecting modern Gateway API requirements)...")
    policy_document = aws.fetch_upstream_lbc_iam_policy()
    aws.create_policy(aws_clients, policy_name, policy_document)
    # Tagged immediately so a later run (this cluster's re-install, or a
    # different cluster whose resolved name happens to land here) can tell
    # this policy is already claimed - see resolve_policy_name().
    aws.tag_policy(aws_clients, policy_arn, naming.OWNER_TAG_KEY, cluster_name)


def verify_oidc_provider(aws_clients: aws.AwsClients, cluster_name: str, account_id: str) -> str:
    log.info("Checking for an IAM OIDC provider associated with the cluster...")
    oidc_issuer = aws.get_cluster_oidc_issuer(aws_clients, cluster_name)
    oidc_provider = oidc_issuer.removeprefix("https://")

    if not aws.oidc_provider_exists(aws_clients, account_id, oidc_provider):
        log.error("No IAM OIDC provider is associated with this cluster.")
        print("IRSA requires one. Create it first, e.g.:", file=sys.stderr)
        print(
            f'  eksctl utils associate-iam-oidc-provider --cluster "{cluster_name}" '
            f'--region "{aws_clients.region}" --approve',
            file=sys.stderr,
        )
        sys.exit(1)

    log.ok(f"IAM OIDC provider found: {oidc_provider}")
    return oidc_provider


def verify_pod_identity_addon(aws_clients: aws.AwsClients, cluster_name: str) -> None:
    log.info("Checking for the EKS Pod Identity Agent addon...")
    if aws.addon_status(aws_clients, cluster_name, "eks-pod-identity-agent") is None:
        log.error("The 'eks-pod-identity-agent' addon is not installed on this cluster.")
        print("Pod Identity requires it. Install it first, e.g.:", file=sys.stderr)
        print(
            f'  aws eks create-addon --cluster-name "{cluster_name}" '
            f'--region "{aws_clients.region}" --addon-name eks-pod-identity-agent',
            file=sys.stderr,
        )
        sys.exit(1)
    log.ok("Pod Identity Agent addon is installed.")


def create_irsa_association(
    aws_clients: aws.AwsClients,
    k8s_client: k8s.K8sClient,
    role_name: str,
    policy_arn: str,
    account_id: str,
    oidc_provider: str,
    cluster_name: str,
) -> None:
    log.info("Generating IAM trust policy document...")
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": f"arn:aws:iam::{account_id}:oidc-provider/{oidc_provider}"
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        f"{oidc_provider}:sub": f"system:serviceaccount:{SA_NAMESPACE}:{SERVICE_ACCOUNT_NAME}",
                        f"{oidc_provider}:aud": "sts.amazonaws.com",
                    }
                },
            }
        ],
    }

    log.info("Configuring IAM Role and policy attachments...")
    if aws.role_exists(aws_clients, role_name):
        log.warn(f"IAM Role '{role_name}' exists. Updating trust relationship...")
    aws.create_or_update_role(aws_clients, role_name, trust_policy)
    aws.attach_role_policy(aws_clients, role_name, policy_arn)
    # Tagged unconditionally (not just on first create) - see
    # resolve_role_name(): cheap, idempotent, and guarantees the tag is
    # present even if a prior interrupted run created the role but never
    # reached this point.
    aws.tag_role(aws_clients, role_name, naming.OWNER_TAG_KEY, cluster_name)

    log.info("Deploying annotated Kubernetes ServiceAccount...")
    role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
    k8s.apply_service_account(k8s_client, SERVICE_ACCOUNT_NAME, SA_NAMESPACE, role_arn)


def create_pod_identity_association(
    aws_clients: aws.AwsClients,
    k8s_client: k8s.K8sClient,
    role_name: str,
    policy_arn: str,
    account_id: str,
    cluster_name: str,
) -> None:
    # Precondition (addon must exist) is checked earlier in main() via
    # verify_pod_identity_addon.
    log.info("Ensuring Kubernetes ServiceAccount exists...")
    k8s.apply_service_account(k8s_client, SERVICE_ACCOUNT_NAME, SA_NAMESPACE, role_arn=None)

    log.info("Generating Pod Identity trust policy document...")
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"Service": "pods.eks.amazonaws.com"},
                "Action": ["sts:AssumeRole", "sts:TagSession"],
            }
        ],
    }

    log.info("Configuring IAM Role and policy attachments...")
    if aws.role_exists(aws_clients, role_name):
        log.warn(f"IAM Role '{role_name}' exists. Updating trust relationship...")
    aws.create_or_update_role(aws_clients, role_name, trust_policy)
    aws.attach_role_policy(aws_clients, role_name, policy_arn)
    aws.tag_role(aws_clients, role_name, naming.OWNER_TAG_KEY, cluster_name)

    log.info("Checking for an existing Pod Identity association...")
    role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
    existing = aws.find_pod_identity_association_id(
        aws_clients, cluster_name, SA_NAMESPACE, SERVICE_ACCOUNT_NAME
    )
    if existing:
        log.ok("Pod Identity association already exists. Skipping creation.")
        return

    log.info("Creating Pod Identity association...")
    aws.create_pod_identity_association(
        aws_clients, cluster_name, SA_NAMESPACE, SERVICE_ACCOUNT_NAME, role_arn
    )


def install_gateway_crds(k8s_client: k8s.K8sClient, channel: str) -> None:
    import urllib.request

    prefix_gw = "https://github.com/kubernetes-sigs/gateway-api"
    crd_urls = {
        "standard": f"{prefix_gw}/releases/download/v1.5.0/standard-install.yaml",
        "experimental": f"{prefix_gw}/releases/download/v1.5.0/experimental-install.yaml",
    }
    if channel not in crd_urls:
        die(f"Unknown channel '{channel}'. Use 'standard' or 'experimental'.")

    log.info(f"Applying Gateway API {channel} CRDs...")
    with urllib.request.urlopen(crd_urls[channel]) as resp:  # noqa: S310
        k8s.apply_yaml_manifests(k8s_client, resp.read().decode())

    log.info("Applying AWS Load Balancer Controller Gateway CRDs...")
    lbc_gw_url = (
        "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/"
        "refs/heads/main/config/crd/gateway/gateway-crds.yaml"
    )
    with urllib.request.urlopen(lbc_gw_url) as resp:  # noqa: S310
        k8s.apply_yaml_manifests(k8s_client, resp.read().decode())


def install_lbc_helm_chart(cluster_name: str, region: str, vpc_id: str, chart_version: str) -> None:
    log.info(f"Upgrading/Installing AWS Load Balancer Controller Chart v{chart_version}...")
    values_yaml = f"""\
clusterName: "{cluster_name}"
vpcId: "{vpc_id}"
region: "{region}"

serviceAccount:
  create: false
  name: "{SERVICE_ACCOUNT_NAME}"

controllerConfig:
  featureGates:
    ALBGatewayAPI: true
    NLBGatewayAPI: true
    GatewayListenerSet: true
"""
    rc = helm.upgrade_install(
        "aws-load-balancer-controller",
        "eks/aws-load-balancer-controller",
        "kube-system",
        chart_version,
        values_yaml,
    )
    if rc != 0:
        die("helm upgrade --install failed.")


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(
        description="Installs the AWS Load Balancer Controller onto an existing EKS cluster.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Required environment variables:\n"
            "  EKS_CLUSTER_NAME   Name of the target EKS cluster\n"
            "  EKS_REGION         AWS region the cluster is in\n"
            "  AWS_PROFILE        AWS CLI profile to use\n"
        ),
    )
    parser.add_argument(
        "auth",
        nargs="?",
        default="irsa",
        choices=["irsa", "pod-identity"],
        help="Authentication mechanism: irsa or pod-identity. Default: irsa",
    )
    args = parser.parse_args()

    cluster_name = os.environ.get("EKS_CLUSTER_NAME") or die("EKS_CLUSTER_NAME is required")
    region = os.environ.get("EKS_REGION") or die("EKS_REGION is required")
    profile = os.environ.get("AWS_PROFILE") or die("AWS_PROFILE is required")

    aws_clients = aws.AwsClients.create(profile=profile, region=region)
    k8s_client = k8s.K8sClient.create()

    verify_requirements(aws_clients, k8s_client)

    log.info("Discovering cluster infrastructure details...")
    account_id = aws.get_account_id(aws_clients)
    vpc_id = aws.get_cluster_vpc_id(aws_clients, cluster_name)

    log.info("Resolving IAM role/policy names (checking for name collisions)...")
    role_name = aws.resolve_role_name(aws_clients, cluster_name)
    policy_name = aws.resolve_policy_name(aws_clients, account_id, cluster_name)
    policy_arn = f"arn:aws:iam::{account_id}:policy/{policy_name}"
    log.info(f"  IAM role   : {role_name}")
    log.info(f"  IAM policy : {policy_name}")

    log.info(f"Verifying prerequisites for '{args.auth}' authentication...")
    oidc_provider = None
    if args.auth == "pod-identity":
        verify_pod_identity_addon(aws_clients, cluster_name)
    else:
        oidc_provider = verify_oidc_provider(aws_clients, cluster_name, account_id)

    create_lbc_iam_policy(aws_clients, policy_name, policy_arn, cluster_name)

    log.info(f"Provisioning IAM binding via '{args.auth}'...")
    if args.auth == "pod-identity":
        create_pod_identity_association(aws_clients, k8s_client, role_name, policy_arn, account_id, cluster_name)
    else:
        assert oidc_provider is not None
        create_irsa_association(aws_clients, k8s_client, role_name, policy_arn, account_id, oidc_provider, cluster_name)

    install_gateway_crds(k8s_client, "experimental")
    helm.add_repo("eks", "https://aws.github.io/eks-charts")
    install_lbc_helm_chart(cluster_name, region, vpc_id, HELM_CHART_VERSION)

    log.ok("Install completed successfully!")


if __name__ == "__main__":
    main()
