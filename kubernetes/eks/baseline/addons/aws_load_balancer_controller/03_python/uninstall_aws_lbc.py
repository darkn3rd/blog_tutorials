#!/usr/bin/env python3
"""uninstall_aws_lbc.py — Removes the AWS Load Balancer Controller from an
existing EKS cluster.

Python port of ../01_cli/uninstall_aws_lbc.sh, using boto3 and the
kubernetes client instead of shelling out to `aws`/`kubectl`/`eksctl`.

Scope note: bash's uninstall_aws_lbc.sh has to handle bindings created by
either the eksctl or aws-cli install path (both are "01_cli"), so its
delete_auth_association() branches on whether an eksctl-owned CloudFormation
stack exists before deciding how to delete the role. install_aws_lbc.py
never uses eksctl or CloudFormation - every binding it creates is pure
boto3 - so that branch is structurally inapplicable here and is dropped
entirely, matching the project's existing "never run one install method's
uninstaller against another method's install" rule (see 02_terraform's
Terraform state vs. 01_cli's CloudFormation stacks for the same reasoning).
Only run this against a cluster set up by install_aws_lbc.py.

Required environment variables:
  EKS_CLUSTER_NAME   Name of the target EKS cluster
  EKS_REGION         AWS region the cluster is in
  AWS_PROFILE        AWS CLI profile to use
"""

from __future__ import annotations

import argparse
import os
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import aws, helm, k8s, log
from lib.errors import die
from lib.python_version import verify_python

POLICY_NAME = "AWSLoadBalancerControllerIAMPolicy"
SERVICE_ACCOUNT_NAME = "aws-load-balancer-controller"
ROLE_NAME = "AmazonEKSLoadBalancerControllerRole"
SA_NAMESPACE = "kube-system"

# Every CRD manifest this script deletes, fetched from source rather than
# hardcoding resource names by hand - a hand-maintained name list is exactly
# how the elbv2.k8s.aws/aga.k8s.aws CRDs went unnoticed for as long as they
# did in the bash version (missed 3 of them, then discovered a 4th only by
# going to find the authoritative source instead of guessing more names).
# The last URL is the Helm chart's own bundled core CRDs
# (TargetGroupBinding/IngressClassParams/ALBTargetControlConfig/
# GlobalAccelerator) - auto-installed by `helm install`, never removed by
# `helm uninstall` (Helm's own deliberate default).
CRD_MANIFEST_URLS = [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml",
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml",
    "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml",
]


def deprovision_load_balancers(aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient, cluster_name: str) -> bool:
    """Deletes every load-balancer-provisioning resource wholesale, polls
    detect_load_balancers() until it reports clean, and if the controller
    hasn't finished within the timeout, forces finalizer removal as a last
    resort and re-checks. Returns False (with an itemized list already
    printed) only if the cluster is STILL not clean after all of that - at
    which point continuing would be walking into a CRD-deletion or
    Helm-uninstall hang.
    """
    log.section("Deprovisioning AWS load balancer resources...")

    for namespace, name in k8s.find_alb_ingresses(k8s_client):
        log.info(f"  Deleting ALB Ingress: {namespace}/{name}")
        k8s.delete_ingress(k8s_client, name, namespace)

    for namespace, name in k8s.find_aws_lb_services(k8s_client):
        log.info(f"  Deleting LB Service: {namespace}/{name}")
        k8s.delete_service(k8s_client, name, namespace)

    for kind in k8s.GATEWAY_API_KINDS:
        k8s.delete_all_of_kind(k8s_client, kind)
    for kind in k8s.LBC_CONFIG_KINDS:
        k8s.delete_all_of_kind(k8s_client, kind)
    for kind in k8s.ELBV2_KINDS:
        k8s.delete_all_of_kind(k8s_client, kind)
    for kind in k8s.AGA_KINDS:
        k8s.delete_all_of_kind(k8s_client, kind)

    # Poll rather than blindly sleep-and-hope: finalizer removal happens
    # asynchronously as the controller reconciles each deletion, so give it
    # real time and confirm rather than assuming a fixed sleep was enough.
    log.info("  Waiting for load balancers to deprovision...")
    interval, timeout = 10, 120
    start = time.time()
    while True:
        if detect_load_balancers(aws_clients, k8s_client, cluster_name, quiet=True):
            log.info("  Confirmed clean.")
            return True
        if time.time() - start >= timeout:
            break
        time.sleep(interval)

    log.error(f"  Not clean after {timeout}s:")
    detect_load_balancers(aws_clients, k8s_client, cluster_name, quiet=False)
    force_clear_stuck_finalizers(aws_clients, k8s_client, cluster_name)

    # A second bounded poll, not a flat sleep: force_clear_stuck_finalizers()
    # now also issues real delete-load-balancer/delete-target-group calls,
    # which are asynchronous - a load balancer sits in "deleting" state for a
    # while rather than disappearing instantly.
    force_timeout = 90
    start = time.time()
    while True:
        if detect_load_balancers(aws_clients, k8s_client, cluster_name, quiet=True):
            log.info("  Confirmed clean after forced cleanup.")
            return True
        if time.time() - start >= force_timeout:
            break
        time.sleep(interval)

    log.error("Still not clean even after forcing finalizer removal - something is fundamentally wrong:")
    detect_load_balancers(aws_clients, k8s_client, cluster_name, quiet=False)
    return False


def detect_load_balancers(
    aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient, cluster_name: str, quiet: bool
) -> bool:
    """Sanity check: confirms nothing that would provision, reference, or
    block deletion of an AWS load balancer remains. Returns True if clean.
    On failure, prints exactly what's left (kind + namespace/name) unless
    quiet=True. Callers must treat False as fatal: deleting the Gateway API
    CRDs or uninstalling the Helm release while this reports uncleared
    resources will cascade onto them and hang, since the controller either
    won't exist (post-Helm-uninstall) or can't act (mid-CRD-deletion).
    """
    remaining: list[str] = []

    for namespace, name in k8s.find_alb_ingresses(k8s_client):
        remaining.append(f"Ingress: {namespace}/{name}")
    for namespace, name in k8s.find_aws_lb_services(k8s_client):
        remaining.append(f"Service: {namespace}/{name}")

    for kind_group in (k8s.GATEWAY_API_KINDS, k8s.LBC_CONFIG_KINDS, k8s.ELBV2_KINDS, k8s.AGA_KINDS):
        for kind in kind_group:
            for namespace, name in k8s.list_all_of_kind(k8s_client, kind):
                entry = f"{namespace}/{name}" if namespace else name
                remaining.append(f"{kind.lower()}: {entry}")

    # Authoritative AWS-side check, independent of walking Kubernetes
    # objects: any load balancer tagged as owned by this cluster is in
    # scope, regardless of whether we can still find (or ever knew to look
    # for) the Kubernetes object that created it.
    for arn in aws.load_balancers_owned_by_cluster(aws_clients, cluster_name):
        remaining.append(f"AWS LoadBalancer: {arn}")

    if remaining:
        if not quiet:
            log.error(f"{len(remaining)} resource(s) that provision or reference an AWS load balancer are still present:")
            for entry in remaining:
                print(f"     {entry}", file=sys.stderr)
            print(
                "  Refusing to delete Gateway API CRDs or uninstall the Helm release while these exist - "
                "both would cascade onto these objects and hang. Investigate (stuck finalizer? controller "
                "error? a resource this script doesn't know to look for?) and re-run.",
                file=sys.stderr,
            )
        return False

    return True


def force_clear_stuck_finalizers(aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient, cluster_name: str) -> None:
    """Last resort, called only after deprovision_load_balancers()'s own
    timeout has already given the controller a full window to reconcile
    deletions properly. Anything still stuck at that point is not going to
    clear on its own - stripping the finalizer trades a possible leaked AWS
    resource for a script that terminates instead of hanging forever; the
    caller re-checks detect_load_balancers() (including its AWS-side tag
    check) immediately after so a real leak is still reported, not silently
    swallowed.
    """
    log.warn("Forcing finalizer removal on stuck resources. This may leave AWS-side")
    log.warn("resources (ALB/NLB/target groups/security groups) orphaned if the")
    log.warn("controller hadn't actually finished deprovisioning them yet.")

    for kind_group in (k8s.GATEWAY_API_KINDS, k8s.LBC_CONFIG_KINDS, k8s.ELBV2_KINDS, k8s.AGA_KINDS):
        for kind in kind_group:
            for namespace, name in k8s.list_all_of_kind(k8s_client, kind):
                log.info(f"  Stripping finalizers: {kind} {namespace + '/' if namespace else ''}{name}")
                k8s.patch_remove_finalizers(k8s_client, kind, name, namespace)

    for namespace, name in k8s.find_alb_ingresses(k8s_client):
        log.info(f"  Stripping finalizers: ingress {namespace}/{name}")
        k8s.patch_remove_ingress_finalizers(k8s_client, name, namespace)

    for namespace, name in k8s.find_aws_lb_services(k8s_client):
        log.info(f"  Stripping finalizers: service {namespace}/{name}")
        k8s.patch_remove_service_finalizers(k8s_client, name, namespace)

    force_delete_orphaned_load_balancers(aws_clients, cluster_name)


def force_delete_orphaned_load_balancers(aws_clients: aws.AwsClients, cluster_name: str) -> None:
    """Stripping Kubernetes finalizers only clears the Kubernetes-side
    bookkeeping - it does nothing to the real AWS load balancer if the
    controller was killed before it ever got to deprovision it. Those are
    real, billed AWS resources that nothing else will ever clean up, so
    this deletes any load balancer + its target groups still tagged as
    owned by this cluster.
    """
    for lb_arn in aws.load_balancers_owned_by_cluster(aws_clients, cluster_name):
        log.info(f"  Deleting orphaned AWS load balancer: {lb_arn}")
        aws.delete_load_balancer_and_target_groups(aws_clients, lb_arn)


def uninstall_lbc_helm_chart() -> None:
    log.section("Removing AWS Load Balancer Controller Helm release...")
    if helm.release_exists("aws-load-balancer-controller", SA_NAMESPACE):
        helm.uninstall("aws-load-balancer-controller", SA_NAMESPACE)
    else:
        log.info("  Helm release not found, skipping.")


def uninstall_gateway_crds(k8s_client: k8s.K8sClient) -> None:
    log.section("Deleting Gateway API + controller core CRDs...")
    for url in CRD_MANIFEST_URLS:
        try:
            with urllib.request.urlopen(url) as resp:  # noqa: S310
                k8s.delete_yaml_manifests(k8s_client, resp.read().decode())
        except Exception as exc:  # noqa: BLE001 - best-effort, mirrors bash's `|| true`
            log.warn(f"  Could not process {url}: {exc}")


def determine_auth_mode(aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient, cluster_name: str) -> str:
    log.section(f"Determining IAM binding type for ServiceAccount {SA_NAMESPACE}/{SERVICE_ACCOUNT_NAME}...")

    role_arn = k8s.get_service_account_annotation(
        k8s_client, SERVICE_ACCOUNT_NAME, SA_NAMESPACE, "eks.amazonaws.com/role-arn"
    )
    if role_arn:
        log.info("  ServiceAccount is annotated with an IAM role -> IRSA.")
        return "irsa"

    # No annotation doesn't necessarily mean Pod Identity - verify a live
    # association actually exists rather than assuming.
    association_id = aws.find_pod_identity_association_id(
        aws_clients, cluster_name, SA_NAMESPACE, SERVICE_ACCOUNT_NAME
    )
    if association_id:
        log.info("  Found an EKS Pod Identity association -> Pod Identity.")
        return "pod-identity"

    log.info("  No IRSA annotation or Pod Identity association found.")
    return ""


def delete_auth_association(aws_clients: aws.AwsClients, k8s_client: k8s.K8sClient, cluster_name: str, auth_mode: str) -> None:
    if auth_mode == "irsa":
        log.section("Extracting IAM role from ServiceAccount annotation...")
        role_arn = k8s.get_service_account_annotation(
            k8s_client, SERVICE_ACCOUNT_NAME, SA_NAMESPACE, "eks.amazonaws.com/role-arn"
        )
        role_name = role_arn.rsplit("/", 1)[-1] if role_arn else None
        if role_name:
            log.info(f"  Found IAM role: {role_name}")
        else:
            log.info("  No IAM role annotation found on ServiceAccount.")

        log.section(f"Deleting ServiceAccount {SA_NAMESPACE}/{SERVICE_ACCOUNT_NAME}...")
        k8s.delete_service_account(k8s_client, SERVICE_ACCOUNT_NAME, SA_NAMESPACE)

        if role_name:
            log.section(f"Deleting IAM Role: {role_name}...")
            aws.delete_role(aws_clients, role_name)
        else:
            log.section("No IAM role to delete, skipping.")

    elif auth_mode == "pod-identity":
        # Pod Identity never annotates or otherwise owns the ServiceAccount
        # object (unlike IRSA), so this needs deleting regardless.
        log.section(f"Deleting ServiceAccount {SA_NAMESPACE}/{SERVICE_ACCOUNT_NAME}...")
        k8s.delete_service_account(k8s_client, SERVICE_ACCOUNT_NAME, SA_NAMESPACE)

        log.section("Extracting IAM role from Pod Identity association...")
        association_id = aws.find_pod_identity_association_id(
            aws_clients, cluster_name, SA_NAMESPACE, SERVICE_ACCOUNT_NAME
        )
        role_name = None
        if association_id:
            role_arn = aws.get_pod_identity_role_arn(
                aws_clients, cluster_name, SA_NAMESPACE, SERVICE_ACCOUNT_NAME
            )
            role_name = role_arn.rsplit("/", 1)[-1] if role_arn else None
            if role_name:
                log.info(f"  Found IAM role: {role_name}")
        else:
            log.info("  No Pod Identity association found.")

        if association_id:
            log.section(f"Deleting Pod Identity association: {association_id}...")
            aws.delete_pod_identity_association(aws_clients, cluster_name, association_id)
        else:
            log.section("No Pod Identity association to delete, skipping.")

        if role_name:
            log.section(f"Deleting IAM Role: {role_name}...")
            aws.delete_role(aws_clients, role_name)
        else:
            log.section("No IAM role to delete, skipping.")

    else:
        log.section("No IAM binding detected, skipping IAM role/association cleanup.")


def delete_iam_policy(aws_clients: aws.AwsClients, policy_arn: str) -> None:
    log.section(f"Deleting IAM Policy: {policy_arn}...")
    if not aws.policy_exists(aws_clients, policy_arn):
        log.info("  IAM Policy not found, skipping.")
        return
    aws.delete_policy(aws_clients, policy_arn)
    log.info("  IAM Policy deleted.")


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(
        description="Removes the AWS Load Balancer Controller from an existing EKS cluster.",
    )
    parser.parse_args()

    cluster_name = os.environ.get("EKS_CLUSTER_NAME") or die("EKS_CLUSTER_NAME is required")
    region = os.environ.get("EKS_REGION") or die("EKS_REGION is required")
    profile = os.environ.get("AWS_PROFILE") or die("AWS_PROFILE is required")

    aws_clients = aws.AwsClients.create(profile=profile, region=region)
    k8s_client = k8s.K8sClient.create()

    account_id = aws.get_account_id(aws_clients)
    policy_arn = f"arn:aws:iam::{account_id}:policy/{POLICY_NAME}"

    # deprovision_load_balancers() deletes every load-balancer-provisioning
    # resource wholesale, polls detect_load_balancers() until it reports
    # clean, and if the controller hasn't finished within the timeout,
    # forces finalizer removal as a last resort and re-checks. It only
    # returns False (with an itemized list already printed) if the cluster
    # is STILL not clean after all of that - at which point continuing
    # would be walking into a CRD-deletion or Helm-uninstall hang, so abort.
    if not deprovision_load_balancers(aws_clients, k8s_client, cluster_name):
        die("Aborting: cluster is not in a clean state for CRD/Helm teardown.")

    # By this point nothing that could block either step remains, so order
    # between them no longer matters for correctness - Helm then CRDs
    # mirrors how they were installed (CRDs, then Helm) run in reverse.
    uninstall_lbc_helm_chart()
    uninstall_gateway_crds(k8s_client)

    auth_mode = determine_auth_mode(aws_clients, k8s_client, cluster_name)
    delete_auth_association(aws_clients, k8s_client, cluster_name, auth_mode)
    delete_iam_policy(aws_clients, policy_arn)

    log.ok("Cleanup completed successfully!")


if __name__ == "__main__":
    main()
