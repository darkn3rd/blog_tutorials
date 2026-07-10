#!/usr/bin/env python3
"""check_aws_lbc_status.py — Surveys an existing AWS Load Balancer Controller
installation and reports:
  - IAM authentication mechanism in use (IRSA, Pod Identity, or a policy
    attached directly to the worker node's IAM role)
  - Gateway API readiness (CRDs installed + controller feature gates)
  - Helm chart version (if Helm-managed) and running controller image version

This is read-only - it does not modify the cluster or AWS account. Python
port of ../../01_cli/scripts/check_aws_lbc_status.sh.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from kubernetes.client import ApiException

from lib import aws, helm, k8s
from lib.errors import die
from lib.python_version import verify_python

GATEWAY_API_CRDS = [
    "gatewayclasses.gateway.networking.k8s.io",
    "gateways.gateway.networking.k8s.io",
    "httproutes.gateway.networking.k8s.io",
    "grpcroutes.gateway.networking.k8s.io",
    "tcproutes.gateway.networking.k8s.io",
    "tlsroutes.gateway.networking.k8s.io",
    "udproutes.gateway.networking.k8s.io",
    "referencegrants.gateway.networking.k8s.io",
    "listenersets.gateway.networking.k8s.io",
]

# UDPRoute is checked/reported above but deliberately excluded here: AWS
# LBC's ALBGatewayAPI/NLBGatewayAPI controllers don't reconcile UDPRoute, so
# its absence shouldn't affect the readiness verdict.
GATEWAY_API_REQUIRED_CRDS = [
    "gatewayclasses.gateway.networking.k8s.io",
    "gateways.gateway.networking.k8s.io",
    "httproutes.gateway.networking.k8s.io",
    "grpcroutes.gateway.networking.k8s.io",
    "tcproutes.gateway.networking.k8s.io",
    "tlsroutes.gateway.networking.k8s.io",
    "referencegrants.gateway.networking.k8s.io",
    "listenersets.gateway.networking.k8s.io",
]

LBC_POLICY_NAME = "AWSLoadBalancerControllerIAMPolicy"


def _get_deployment(k8s_client: k8s.K8sClient, deployment_name: str, namespace: str):
    try:
        return k8s_client.apps_v1.read_namespaced_deployment(deployment_name, namespace)
    except ApiException as exc:
        if exc.status == 404:
            return None
        raise


def check_controller_installed(k8s_client: k8s.K8sClient, deployment_name: str, namespace: str) -> bool:
    print()
    print("==> Checking for AWS Load Balancer Controller deployment...")
    deployment = _get_deployment(k8s_client, deployment_name, namespace)
    if deployment is None:
        print(f"❌ Deployment '{namespace}/{deployment_name}' not found.")
        print("The AWS Load Balancer Controller does not appear to be installed.")
        return False

    ready = f"{deployment.status.ready_replicas or 0}/{deployment.status.replicas or 0}"
    print(f"✅ Found deployment {namespace}/{deployment_name} (ready: {ready})")
    return True


def check_node_iam_role(aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient, namespace: str) -> tuple[str | None, bool]:
    """Third fallback auth path: no IRSA annotation, no Pod Identity
    association - check whether the underlying EC2 node's own instance
    profile role has the LBC policy attached (an older/simpler pattern with
    no per-pod IAM binding).
    """
    print("  Checking whether the LBC policy is attached directly to the node's IAM role...")

    pods = k8s_client.core_v1.list_namespaced_pod(
        namespace, label_selector="app.kubernetes.io/name=aws-load-balancer-controller"
    ).items
    if not pods or not pods[0].spec.node_name:
        print("  Could not determine controller pod's node (no running pods found).")
        return None, False

    node_name = pods[0].spec.node_name
    node = k8s_client.core_v1.read_node(node_name)
    provider_id = node.spec.provider_id or ""
    instance_id = provider_id.rsplit("/", 1)[-1] if provider_id else ""

    if not instance_id or instance_id == provider_id:
        print(f"  Node '{node_name}' has no EC2 instance ID (possibly Fargate) - skipping.")
        return None, False

    profile_arn = aws.instance_profile_arn_for_instance(aws_clients, instance_id)
    if not profile_arn:
        print(f"  No instance profile found for instance {instance_id}.")
        return None, False

    profile_name = profile_arn.rsplit("/", 1)[-1]
    role_name = aws.get_instance_profile_role_name(aws_clients, profile_name)
    if not role_name:
        print(f"  Could not resolve IAM role from instance profile '{profile_name}'.")
        return None, False

    if aws.role_has_policy_attached(aws_clients, role_name, LBC_POLICY_NAME):
        print(f"  ✅ Node role '{role_name}' (instance {instance_id}) has {LBC_POLICY_NAME} attached.")
        return role_name, True

    print(f"  Node role '{role_name}' does NOT have {LBC_POLICY_NAME} attached.")
    return None, False


def determine_auth_mode(
    aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient, cluster_name: str, sa_name: str, namespace: str
) -> tuple[str, str]:
    print()
    print("==> Determining IAM authentication mechanism...")

    sa_role_arn = k8s.get_service_account_annotation(k8s_client, sa_name, namespace, "eks.amazonaws.com/role-arn")
    if sa_role_arn:
        print(f"  ✅ IRSA detected - ServiceAccount annotated with role: {sa_role_arn}")
        return "irsa", sa_role_arn

    association_id = aws.find_pod_identity_association_id(aws_clients, cluster_name, namespace, sa_name)
    if association_id:
        role_arn = aws.get_pod_identity_role_arn(aws_clients, cluster_name, namespace, sa_name) or ""
        print(f"  ✅ Pod Identity detected - association bound to role: {role_arn}")
        return "pod-identity", role_arn

    print("  No IRSA annotation or Pod Identity association found.")
    role_name, has_policy = check_node_iam_role(aws_clients, k8s_client, namespace)
    if has_policy and role_name:
        return "node-iam-role", role_name

    print("  ⚠️  Could not determine how the controller obtains AWS credentials.")
    return "unknown", ""


def check_gateway_api_crds(k8s_client: k8s.K8sClient) -> tuple[list[str], list[str]]:
    print()
    print("==> Checking Gateway API CRDs...")
    missing: list[str] = []
    missing_required: list[str] = []

    for crd_name in GATEWAY_API_CRDS:
        try:
            crd = k8s_client.apiextensions_v1.read_custom_resource_definition(crd_name)
            versions = ", ".join(v.name for v in crd.spec.versions)
            print(f"  ✅ {crd_name} (versions served: {versions})")
        except ApiException as exc:
            if exc.status != 404:
                raise
            print(f"  ❌ {crd_name} not installed")
            missing.append(crd_name)
            if crd_name in GATEWAY_API_REQUIRED_CRDS:
                missing_required.append(crd_name)

    return missing, missing_required


def check_controller_feature_gates(k8s_client: k8s.K8sClient, deployment_name: str, namespace: str) -> dict[str, bool]:
    print()
    print("==> Checking controller feature gates...")
    deployment = _get_deployment(k8s_client, deployment_name, namespace)
    args = []
    if deployment is not None:
        args = deployment.spec.template.spec.containers[0].args or []

    feature_gates = ""
    for arg in args:
        match = re.match(r"--feature-gates=(\S+)", arg)
        if match:
            feature_gates = match.group(1)
            break

    if not feature_gates:
        print("  No --feature-gates argument found on the controller.")
        return {"ALBGatewayAPI": False, "NLBGatewayAPI": False, "GatewayListenerSet": False}

    print(f"  Raw: --feature-gates={feature_gates}")
    gates = {
        "ALBGatewayAPI": "ALBGatewayAPI=true" in feature_gates,
        "NLBGatewayAPI": "NLBGatewayAPI=true" in feature_gates,
        "GatewayListenerSet": "GatewayListenerSet=true" in feature_gates,
    }
    print(f"    ALBGatewayAPI:      {gates['ALBGatewayAPI']}")
    print(f"    NLBGatewayAPI:      {gates['NLBGatewayAPI']}")
    print(f"    GatewayListenerSet: {gates['GatewayListenerSet']}")
    return gates


def check_helm_release(release_name: str, namespace: str) -> dict | None:
    print()
    print("==> Checking Helm release...")
    info = helm.get_release_info(release_name, namespace)
    if info is None:
        print(f"  Not Helm-managed (no release '{release_name}' found in namespace {namespace}).")
        return None
    print(f"  ✅ Helm release: {info['chart']} (app_version: {info['app_version']}, status: {info['status']})")
    return info


def check_controller_image_version(k8s_client: k8s.K8sClient, deployment_name: str, namespace: str) -> tuple[str, str]:
    print()
    print("==> Checking controller image version...")
    deployment = _get_deployment(k8s_client, deployment_name, namespace)
    image = deployment.spec.template.spec.containers[0].image if deployment is not None else ""

    if not image:
        print("  Could not read controller image.")
        return "", ""

    tag = image.rsplit(":", 1)[-1] if ":" in image else ""
    print(f"  ✅ Controller image: {image}")
    return image, tag


def print_summary(
    deployment_name: str,
    namespace: str,
    image: str,
    tag: str,
    helm_info: dict | None,
    auth_mode: str,
    auth_role: str,
    missing_crds: list[str],
    missing_required: list[str],
    gates: dict[str, bool],
) -> None:
    print()
    print("=" * 40)
    print(" AWS Load Balancer Controller Status")
    print("=" * 40)
    print(f"Deployment:          {namespace}/{deployment_name}")
    print(f"Controller version:  {tag or 'unknown'}")
    print(f"Controller image:    {image or 'unknown'}")
    if helm_info:
        print(f"Helm chart:          {helm_info['chart']} (app_version: {helm_info['app_version']})")
    else:
        print("Helm chart:          not Helm-managed")

    print()
    print(f"IAM authentication:  {auth_mode}")
    if auth_mode == "irsa":
        print(f"  Role: {auth_role} (via IRSA)")
    elif auth_mode == "pod-identity":
        print(f"  Role: {auth_role} (via Pod Identity)")
    elif auth_mode == "node-iam-role":
        print(f"  Role: {auth_role} attached directly to the node's instance profile (no per-pod IAM binding)")
    else:
        print("  Could not determine how the controller obtains AWS credentials.")

    print()
    print("Gateway API readiness:")
    print(f"  CRDs missing: {len(missing_crds)} / {len(GATEWAY_API_CRDS)}")
    for crd in missing_crds:
        print(f"    - {crd}")
    print(
        f"  Note: UDPRoute is not reconciled by AWS LBC {tag or '<unknown version>'} "
        "(ALBGatewayAPI/NLBGatewayAPI don't use it), so its absence doesn't affect the readiness verdict below."
    )
    print(f"  ALBGatewayAPI feature gate:      {gates['ALBGatewayAPI']}")
    print(f"  NLBGatewayAPI feature gate:      {gates['NLBGatewayAPI']}")
    print(f"  GatewayListenerSet feature gate: {gates['GatewayListenerSet']}")

    if not missing_required and gates["ALBGatewayAPI"] and gates["NLBGatewayAPI"]:
        print("  ✅ Gateway API ready (ALB + NLB)")
    else:
        print("  ⚠️  Gateway API not fully ready - see details above")


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(
        description=(
            "Surveys an existing AWS Load Balancer Controller installation and reports the IAM "
            "auth mechanism in use, Gateway API readiness, and Helm/controller versions. Read-only "
            "- does not modify the cluster or AWS account."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Required environment variables:\n"
            "  EKS_CLUSTER_NAME   Name of the target EKS cluster\n"
            "  EKS_REGION         AWS region the cluster is in\n"
            "  AWS_PROFILE        AWS CLI profile to use\n\n"
            "Optional environment variables:\n"
            "  DEPLOYMENT_NAME    Controller deployment name. Default: aws-load-balancer-controller\n"
            "  SA_NAME            ServiceAccount name. Default: aws-load-balancer-controller\n"
            "  SA_NAMESPACE       Namespace the controller runs in. Default: kube-system\n"
            "  HELM_RELEASE_NAME  Helm release name to look up. Default: aws-load-balancer-controller\n"
        ),
    )
    parser.parse_args()

    cluster_name = os.environ.get("EKS_CLUSTER_NAME") or die("EKS_CLUSTER_NAME is required")
    region = os.environ.get("EKS_REGION") or die("EKS_REGION is required")
    profile = os.environ.get("AWS_PROFILE") or die("AWS_PROFILE is required")

    deployment_name = os.environ.get("DEPLOYMENT_NAME", "aws-load-balancer-controller")
    sa_name = os.environ.get("SA_NAME", "aws-load-balancer-controller")
    sa_namespace = os.environ.get("SA_NAMESPACE", "kube-system")
    helm_release_name = os.environ.get("HELM_RELEASE_NAME", "aws-load-balancer-controller")

    aws_clients = aws.AwsClients.create(profile=profile, region=region)
    k8s_client = k8s.K8sClient.create()
    k8s.verify_k8s_connectivity(k8s_client)

    if not check_controller_installed(k8s_client, deployment_name, sa_namespace):
        sys.exit(1)

    auth_mode, auth_role = determine_auth_mode(aws_clients, k8s_client, cluster_name, sa_name, sa_namespace)
    missing_crds, missing_required = check_gateway_api_crds(k8s_client)
    gates = check_controller_feature_gates(k8s_client, deployment_name, sa_namespace)
    helm_info = check_helm_release(helm_release_name, sa_namespace)
    image, tag = check_controller_image_version(k8s_client, deployment_name, sa_namespace)

    print_summary(
        deployment_name, sa_namespace, image, tag, helm_info, auth_mode, auth_role, missing_crds, missing_required, gates
    )


if __name__ == "__main__":
    main()
