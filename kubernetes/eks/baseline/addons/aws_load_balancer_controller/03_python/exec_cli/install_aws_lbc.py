#!/usr/bin/env python3
"""install_aws_lbc.py — Installs the AWS Load Balancer Controller onto an
existing EKS cluster by calling the `aws`, `kubectl`, and `eksctl` CLI tools
via subprocess - a Python-scripted version of running those commands by
hand, rather than using boto3/kubernetes-client to call the APIs directly.

Usage:
  install_aws_lbc.py [tool] [auth]

Arguments:
  tool   Which CLI provisions the IAM binding: eksctl or aws-cli. Default: eksctl
  auth   Authentication mechanism: irsa or pod-identity. Default: irsa

Options:
  -h, --help   Show this help message and exit

Required environment variables:
  EKS_CLUSTER_NAME   Name of the target EKS cluster
  EKS_REGION         AWS region the cluster is in
  AWS_PROFILE        AWS CLI profile to use

Examples:
  EKS_CLUSTER_NAME=my-cluster EKS_REGION=us-east-2 AWS_PROFILE=default ./install_aws_lbc.py
  EKS_CLUSTER_NAME=my-cluster EKS_REGION=us-east-2 AWS_PROFILE=default ./install_aws_lbc.py aws-cli pod-identity
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import log, naming, run
from lib.errors import die
from lib.python_version import verify_python

HELM_CHART_VERSION = "3.4.0"
SERVICE_ACCOUNT_NAME = "aws-load-balancer-controller"
SA_NAMESPACE = "kube-system"


def verify_binaries(*tools: str) -> None:
    log.info("Checking required local CLI tools...")
    missing = [t for t in tools if shutil.which(t) is None]
    if missing:
        die(f"Missing required CLI utilities: {', '.join(missing)}. Please install them and retry.")
    log.ok("All CLI tools available.")


def verify_kubernetes_connectivity() -> None:
    log.info("Checking Kubernetes cluster connection...")
    if not run.run_ok(["kubectl", "cluster-info"]):
        die("Cannot connect to the Kubernetes cluster. Verify your KUBECONFIG context.")
    context = run.run(["kubectl", "config", "current-context"])
    log.ok(f"Cluster connection verified: {context}")


def verify_aws_connectivity(profile: str) -> None:
    log.info("Checking AWS CLI connectivity and credentials...")
    if not run.run_ok(["aws", "sts", "get-caller-identity", "--profile", profile]):
        die(f"AWS authentication failed using profile '{profile}'. Run 'aws sso login' or check your credentials.")
    log.ok("AWS connection verified successfully.")


def verify_requirements(tool_mode: str, profile: str) -> None:
    tools = ["aws", "kubectl", "helm", "jq"]
    if tool_mode == "eksctl":
        tools.append("eksctl")
    verify_binaries(*tools)
    verify_kubernetes_connectivity()
    verify_aws_connectivity(profile)


def create_lbc_iam_policy(profile: str, region: str, policy_name: str, policy_arn: str) -> None:
    log.info("Checking for existing LBC IAM Policy...")
    if run.run_ok(["aws", "iam", "get-policy", "--policy-arn", policy_arn, "--profile", profile]):
        log.ok("IAM Policy already exists. Skipping creation.")
        return

    log.info("Creating LBC IAM Policy (Injecting modern Gateway API requirements)...")
    import urllib.request

    url = (
        "https://raw.githubusercontent.com/kubernetes-sigs/"
        "aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
    )
    with urllib.request.urlopen(url) as resp:  # noqa: S310
        policy_document = json.loads(resp.read())

    policy_document["Statement"].append(
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:ModifyListenerAttributes",
            ],
            "Resource": "*",
        }
    )

    run.run(
        [
            "aws", "iam", "create-policy",
            "--policy-name", policy_name,
            "--policy-document", json.dumps(policy_document),
            "--profile", profile,
        ]
    )


def verify_oidc_provider(cluster_name: str, region: str, profile: str, account_id: str) -> str:
    log.info("Checking for an IAM OIDC provider associated with the cluster...")
    oidc_url = run.run(
        [
            "aws", "eks", "describe-cluster",
            "--name", cluster_name, "--region", region, "--profile", profile,
            "--query", "cluster.identity.oidc.issuer", "--output", "text",
        ]
    )
    oidc_provider = oidc_url.removeprefix("https://")

    provider_arn = f"arn:aws:iam::{account_id}:oidc-provider/{oidc_provider}"
    if not run.run_ok(["aws", "iam", "get-open-id-connect-provider", "--open-id-connect-provider-arn", provider_arn, "--profile", profile]):
        log.error("No IAM OIDC provider is associated with this cluster.")
        print("IRSA requires one. Create it first, e.g.:", file=sys.stderr)
        print(
            f'  eksctl utils associate-iam-oidc-provider --cluster "{cluster_name}" '
            f'--region "{region}" --approve',
            file=sys.stderr,
        )
        sys.exit(1)

    log.ok(f"IAM OIDC provider found: {oidc_provider}")
    return oidc_provider


def verify_pod_identity_addon(cluster_name: str, region: str, profile: str) -> None:
    log.info("Checking for the EKS Pod Identity Agent addon...")
    if not run.run_ok(
        ["aws", "eks", "describe-addon", "--cluster-name", cluster_name, "--region", region,
         "--addon-name", "eks-pod-identity-agent", "--profile", profile]
    ):
        log.error("The 'eks-pod-identity-agent' addon is not installed on this cluster.")
        print("Pod Identity requires it. Install it first, e.g.:", file=sys.stderr)
        print(
            f'  aws eks create-addon --cluster-name "{cluster_name}" '
            f'--region "{region}" --addon-name eks-pod-identity-agent',
            file=sys.stderr,
        )
        sys.exit(1)
    log.ok("Pod Identity Agent addon is installed.")


def create_or_update_role(role_name: str, trust_policy: dict, profile: str) -> None:
    document = json.dumps(trust_policy)
    if run.run_ok(["aws", "iam", "get-role", "--role-name", role_name, "--profile", profile]):
        log.warn(f"IAM Role '{role_name}' exists. Updating trust relationship...")
        run.run(["aws", "iam", "update-assume-role-policy", "--role-name", role_name,
                  "--policy-document", document, "--profile", profile])
    else:
        run.run(["aws", "iam", "create-role", "--role-name", role_name,
                  "--assume-role-policy-document", document, "--profile", profile])


def create_lbc_irsa_association(
    tool_mode: str, cluster_name: str, region: str, profile: str,
    role_name: str, policy_arn: str, account_id: str, oidc_provider: str,
) -> None:
    if tool_mode == "aws-cli":
        create_lbc_irsa_association_awscli(cluster_name, region, profile, role_name, policy_arn, account_id, oidc_provider)
    else:
        create_lbc_irsa_association_eksctl(cluster_name, region, policy_arn)


def create_lbc_irsa_association_eksctl(cluster_name: str, region: str, policy_arn: str) -> None:
    log.info("Associating IAM Service Account via eksctl...")
    rc = run.run_streamed(
        [
            "eksctl", "create", "iamserviceaccount",
            f"--cluster={cluster_name}",
            "--namespace=kube-system",
            f"--name={SERVICE_ACCOUNT_NAME}",
            f"--attach-policy-arn={policy_arn}",
            "--override-existing-serviceaccounts",
            "--region", region,
            "--approve",
        ]
    )
    if rc != 0:
        die("eksctl create iamserviceaccount failed.")

    log.info("Sleeping 15 seconds to allow AWS OIDC replication to settle...")
    time.sleep(15)


def create_lbc_irsa_association_awscli(
    cluster_name: str, region: str, profile: str, role_name: str, policy_arn: str,
    account_id: str, oidc_provider: str,
) -> None:
    log.info("Generating temporary IAM trust policy document...")
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"Federated": f"arn:aws:iam::{account_id}:oidc-provider/{oidc_provider}"},
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
    create_or_update_role(role_name, trust_policy, profile)
    run.run(["aws", "iam", "attach-role-policy", "--role-name", role_name, "--policy-arn", policy_arn, "--profile", profile])

    log.info("Deploying annotated Kubernetes ServiceAccount...")
    role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
    manifest = f"""\
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: {SERVICE_ACCOUNT_NAME}
  name: {SERVICE_ACCOUNT_NAME}
  namespace: {SA_NAMESPACE}
  annotations:
    eks.amazonaws.com/role-arn: {role_arn}
"""
    run.run(["kubectl", "apply", "-f", "-"], input_text=manifest)


def ensure_service_account() -> None:
    log.info("Ensuring Kubernetes ServiceAccount exists...")
    manifest = f"""\
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: {SERVICE_ACCOUNT_NAME}
  name: {SERVICE_ACCOUNT_NAME}
  namespace: {SA_NAMESPACE}
"""
    run.run(["kubectl", "apply", "-f", "-"], input_text=manifest)


def create_lbc_pod_identity_association(
    tool_mode: str, cluster_name: str, region: str, profile: str,
    role_name: str, policy_arn: str, account_id: str,
) -> None:
    # Precondition (addon must exist) is checked earlier in main() via
    # verify_pod_identity_addon.
    ensure_service_account()

    if tool_mode == "aws-cli":
        create_lbc_pod_identity_association_awscli(cluster_name, region, profile, role_name, policy_arn, account_id)
    else:
        create_lbc_pod_identity_association_eksctl(cluster_name, region, policy_arn)


def create_lbc_pod_identity_association_eksctl(cluster_name: str, region: str, policy_arn: str) -> None:
    log.info("Checking for an existing Pod Identity association...")
    existing = run.run_json(
        [
            "eksctl", "get", "podidentityassociation",
            f"--cluster={cluster_name}",
            "--namespace=kube-system",
            f"--service-account-name={SERVICE_ACCOUNT_NAME}",
            "--region", region,
            "--output", "json",
        ]
    )
    if existing:
        log.ok("Pod Identity association already exists. Skipping creation.")
        return

    log.info("Creating Pod Identity association via eksctl...")
    rc = run.run_streamed(
        [
            "eksctl", "create", "podidentityassociation",
            f"--cluster={cluster_name}",
            "--namespace=kube-system",
            f"--service-account-name={SERVICE_ACCOUNT_NAME}",
            f"--permission-policy-arns={policy_arn}",
            "--region", region,
        ]
    )
    if rc != 0:
        die("eksctl create podidentityassociation failed.")


def create_lbc_pod_identity_association_awscli(
    cluster_name: str, region: str, profile: str, role_name: str, policy_arn: str, account_id: str,
) -> None:
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
    create_or_update_role(role_name, trust_policy, profile)
    run.run(["aws", "iam", "attach-role-policy", "--role-name", role_name, "--policy-arn", policy_arn, "--profile", profile])

    log.info("Checking for an existing Pod Identity association...")
    assoc_id = run.run(
        [
            "aws", "eks", "list-pod-identity-associations",
            "--cluster-name", cluster_name, "--region", region, "--profile", profile,
            "--namespace", SA_NAMESPACE, "--service-account", SERVICE_ACCOUNT_NAME,
            "--query", "associations[0].associationId", "--output", "text",
        ],
        check=False,
    )
    if assoc_id and assoc_id != "None":
        log.ok("Pod Identity association already exists. Skipping creation.")
        return

    log.info("Creating Pod Identity association...")
    role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
    run.run(
        [
            "aws", "eks", "create-pod-identity-association",
            "--cluster-name", cluster_name, "--region", region, "--profile", profile,
            "--namespace", SA_NAMESPACE, "--service-account", SERVICE_ACCOUNT_NAME,
            "--role-arn", role_arn,
        ]
    )


def add_helm_repo() -> None:
    run.run(["helm", "repo", "add", "eks", "https://aws.github.io/eks-charts"], check=False)
    run.run(["helm", "repo", "update", "eks"])


def install_gateway_crds(channel: str) -> None:
    prefix_gw = "https://github.com/kubernetes-sigs/gateway-api"
    crd_urls = {
        "standard": f"{prefix_gw}/releases/download/v1.5.0/standard-install.yaml",
        "experimental": f"{prefix_gw}/releases/download/v1.5.0/experimental-install.yaml",
    }
    if channel not in crd_urls:
        die(f"Unknown channel '{channel}'. Use 'standard' or 'experimental'.")

    log.info(f"Applying Gateway API {channel} CRDs...")
    run.run(["kubectl", "apply", "--server-side", "--force-conflicts", "--filename", crd_urls[channel]])

    log.info("Applying AWS Load Balancer Controller Gateway CRDs...")
    lbc_gw_url = (
        "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/"
        "refs/heads/main/config/crd/gateway/gateway-crds.yaml"
    )
    run.run(["kubectl", "apply", "--server-side", "--force-conflicts", "--filename", lbc_gw_url])


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
    rc = run.run_streamed(
        [
            "helm", "upgrade", "--install",
            "--version", chart_version,
            "--namespace", "kube-system",
            "aws-load-balancer-controller", "eks/aws-load-balancer-controller",
            "--values", "-",
        ],
        input_text=values_yaml,
    )
    if rc != 0:
        die("helm upgrade --install failed.")


def discover_cluster_info(cluster_name: str, region: str, profile: str) -> tuple[str, str]:
    log.info("Discovering cluster infrastructure details...")
    account_id = run.run(["aws", "sts", "get-caller-identity", "--profile", profile, "--query", "Account", "--output", "text"])
    vpc_id = run.run(
        [
            "aws", "eks", "describe-cluster", "--name", cluster_name, "--region", region, "--profile", profile,
            "--query", "cluster.resourcesVpcConfig.vpcId", "--output", "text",
        ]
    )
    return account_id, vpc_id


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
    parser.add_argument("tool", nargs="?", default="eksctl", choices=["eksctl", "aws-cli"],
                         help="Which CLI provisions the IAM binding. Default: eksctl")
    parser.add_argument("auth", nargs="?", default="irsa", choices=["irsa", "pod-identity"],
                         help="Authentication mechanism. Default: irsa")
    args = parser.parse_args()

    cluster_name = os.environ.get("EKS_CLUSTER_NAME") or die("EKS_CLUSTER_NAME is required")
    region = os.environ.get("EKS_REGION") or die("EKS_REGION is required")
    profile = os.environ.get("AWS_PROFILE") or die("AWS_PROFILE is required")

    verify_requirements(args.tool, profile)

    account_id, vpc_id = discover_cluster_info(cluster_name, region, profile)
    # Only the aws-cli path needs an explicit, collision-safe role name -
    # eksctl generates its own uniquely-named role via CloudFormation. The
    # policy is shared by both tool paths, so it's always scoped.
    role_name = naming.role_name(cluster_name)
    policy_name = naming.policy_name(cluster_name)
    policy_arn = f"arn:aws:iam::{account_id}:policy/{policy_name}"
    log.info(f"  IAM policy : {policy_name}")
    if args.tool == "aws-cli":
        log.info(f"  IAM role   : {role_name}")

    log.info(f"Verifying prerequisites for '{args.auth}' authentication...")
    oidc_provider = None
    if args.auth == "pod-identity":
        verify_pod_identity_addon(cluster_name, region, profile)
    else:
        oidc_provider = verify_oidc_provider(cluster_name, region, profile, account_id)

    create_lbc_iam_policy(profile, region, policy_name, policy_arn)

    log.info(f"Provisioning IAM binding via '{args.auth}' using '{args.tool}'...")
    if args.auth == "pod-identity":
        create_lbc_pod_identity_association(args.tool, cluster_name, region, profile, role_name, policy_arn, account_id)
    else:
        assert oidc_provider is not None
        create_lbc_irsa_association(args.tool, cluster_name, region, profile, role_name, policy_arn, account_id, oidc_provider)

    install_gateway_crds("experimental")
    add_helm_repo()
    install_lbc_helm_chart(cluster_name, region, vpc_id, HELM_CHART_VERSION)

    log.ok("Install completed successfully!")


if __name__ == "__main__":
    main()
