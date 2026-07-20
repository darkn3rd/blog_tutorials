#!/usr/bin/env python3
"""uninstall_aws_lbc.py — Removes the AWS Load Balancer Controller from an
existing EKS cluster by calling the `aws`, `kubectl`, and `eksctl` CLI tools
via subprocess.

Handles bindings created by either install_aws_lbc.py's eksctl or aws-cli
tool path: if eksctl (via CloudFormation) created the ServiceAccount/IAM
role pair, eksctl deletes it - mutating a CloudFormation-owned role
directly (attach/detach a policy, delete it, etc.) outside the stack
diverges the stack's tracked state from live AWS state, since
CloudFormation doesn't re-derive what's actually attached, it trusts its
own template. Only when there's no CloudFormation stack at all (the
aws-cli path never involves eksctl) does this fall back to direct IAM API
calls.

Required environment variables:
  EKS_CLUSTER_NAME   Name of the target EKS cluster
  EKS_REGION         AWS region the cluster is in
  AWS_PROFILE        AWS CLI profile to use
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import log, naming, run
from lib.errors import die
from lib.python_version import verify_python

SERVICE_ACCOUNT_NAME = "aws-load-balancer-controller"
SA_NAMESPACE = os.environ.get("SA_NAMESPACE", "kube-system")

# Fetched from source rather than hardcoding resource names by hand - a
# hand-maintained name list is an easy way to silently miss a CRD (e.g.
# elbv2.k8s.aws/aga.k8s.aws ones) that the chart bundles but nothing else
# in this script's flow would ever remove. The last URL is the Helm
# chart's own bundled core CRDs (TargetGroupBinding/IngressClassParams/
# ALBTargetControlConfig/GlobalAccelerator) - auto-installed by
# `helm install`, never removed by `helm uninstall` (Helm's own
# deliberate default).
CRD_MANIFEST_URLS = [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml",
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml",
    "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml",
]

# Every Gateway API kind this script's CRD deletion removes. Since the CRDs
# themselves are deleted wholesale regardless of who owns any given
# instance, every live instance of every one of these kinds is in scope -
# there is no such thing as "not ours" here.
GATEWAY_API_KINDS = ["gateway", "httproute", "grpcroute", "tcproute", "tlsroute", "udproute", "referencegrant", "gatewayclass"]
LBC_CONFIG_KINDS = ["loadbalancerconfiguration", "targetgroupconfiguration", "listenerruleconfiguration"]
ELBV2_KINDS = ["targetgroupbinding", "ingressclassparams", "albtargetcontrolconfigs"]
AGA_KINDS = ["globalaccelerator"]


# ── kubectl kind helpers ────────────────────────────────────────────────


def api_group_installed(group: str) -> bool:
    return run.run_ok(["kubectl", "api-resources", f"--api-group={group}"])


def list_all_of_kind(kind: str) -> list[str]:
    """Returns "namespace/name" (or bare "name" for cluster-scoped kinds)
    for every live instance of `kind`. Empty if the kind's CRD isn't
    installed.
    """
    output = run.run(["kubectl", "get", kind, "--all-namespaces", "-o", "json"], check=False)
    if not output:
        return []
    data = json.loads(output)
    entries = []
    for item in data.get("items", []):
        ns = item["metadata"].get("namespace")
        name = item["metadata"]["name"]
        entries.append(f"{ns}/{name}" if ns else name)
    return entries


def delete_all_of_kind(kind: str, label: str | None = None) -> None:
    """Deletes every live instance of `kind`. --wait=false: issue the
    delete and return immediately rather than blocking for full removal -
    if the controller is already gone, kubectl's default --wait=true would
    block forever on a finalizer that never clears. The poll-and-force-
    clear loop in deprovision_aws_load_balancers() is the one place that
    actually waits, on a bounded timeout.
    """
    if not run.run(["kubectl", "get", kind, "--all-namespaces", "-o", "name"], check=False):
        return
    log.info(f"  Deleting all {label or kind}...")
    run.run(["kubectl", "delete", kind, "--all", "--all-namespaces", "--ignore-not-found=true", "--wait=false"], check=False)


def find_alb_ingresses() -> list[str]:
    """Returns "namespace/name" for every Ingress that will provision an
    ALB. Matched by IngressClass *controller* (ingress.k8s.aws/alb), not
    by an IngressClass literally named "alb" - the IngressClass name is
    arbitrary. Also matches the deprecated kubernetes.io/ingress.class
    annotation literal value "alb" directly (a fixed value AWS LBC's own
    docs specify, not a user-arbitrary name), so an Ingress relying on
    only that annotation (no IngressClass object at all) is still caught.
    """
    ic_output = run.run(["kubectl", "get", "ingressclass", "-o", "json"], check=False)
    alb_classes: set[str] = set()
    if ic_output:
        for ic in json.loads(ic_output).get("items", []):
            if ic.get("spec", {}).get("controller") == "ingress.k8s.aws/alb":
                alb_classes.add(ic["metadata"]["name"])

    ing_output = run.run(["kubectl", "get", "ingress", "--all-namespaces", "-o", "json"], check=False)
    if not ing_output:
        return []

    matches = []
    for ing in json.loads(ing_output).get("items", []):
        annotations = ing["metadata"].get("annotations", {})
        annotation_class = annotations.get("kubernetes.io/ingress.class")
        spec_class = ing.get("spec", {}).get("ingressClassName")
        if (
            (annotation_class and annotation_class in alb_classes)
            or (spec_class and spec_class in alb_classes)
            or annotation_class == "alb"
        ):
            matches.append(f"{ing['metadata']['namespace']}/{ing['metadata']['name']}")
    return matches


def find_aws_lb_services() -> list[str]:
    """Returns "namespace/name" for every Service that will provision an
    NLB. Matched by the fixed annotation values / loadBalancerClass prefix
    the AWS LBC itself recognizes - these are not user-renameable.
    """
    output = run.run(["kubectl", "get", "svc", "--all-namespaces", "-o", "json"], check=False)
    if not output:
        return []

    matches = []
    for svc in json.loads(output).get("items", []):
        spec = svc.get("spec", {})
        if spec.get("type") != "LoadBalancer":
            continue
        annotations = svc["metadata"].get("annotations", {})
        lb_type = annotations.get("service.beta.kubernetes.io/aws-load-balancer-type")
        lb_class = spec.get("loadBalancerClass", "") or ""
        if lb_type in ("nlb", "external", "nlb-ip") or lb_class.startswith("service.k8s.aws/"):
            matches.append(f"{svc['metadata']['namespace']}/{svc['metadata']['name']}")
    return matches


# ── load balancer deprovisioning ────────────────────────────────────────


def deprovision_aws_load_balancers(cluster_name: str, region: str, profile: str) -> bool:
    log.section("Deprovisioning AWS load balancer resources...")

    for entry in find_alb_ingresses():
        ns, name = entry.split("/", 1)
        log.info(f"  Deleting ALB Ingress: {entry}")
        run.run(["kubectl", "delete", "ingress", name, "-n", ns, "--ignore-not-found=true", "--wait=false"], check=False)

    for entry in find_aws_lb_services():
        ns, name = entry.split("/", 1)
        log.info(f"  Deleting LB Service: {entry}")
        run.run(["kubectl", "delete", "svc", name, "-n", ns, "--ignore-not-found=true", "--wait=false"], check=False)

    if api_group_installed("gateway.networking.k8s.io"):
        for kind in GATEWAY_API_KINDS:
            delete_all_of_kind(kind)

    for kind in LBC_CONFIG_KINDS:
        if api_group_installed("gateway.k8s.aws"):
            delete_all_of_kind(kind)
    for kind in ELBV2_KINDS:
        if api_group_installed("elbv2.k8s.aws"):
            delete_all_of_kind(kind)
    for kind in AGA_KINDS:
        if api_group_installed("aga.k8s.aws"):
            delete_all_of_kind(kind)

    log.info("  Waiting for load balancers to deprovision...")
    interval, timeout = 10, 120
    start = time.time()
    while True:
        if detect_aws_load_balancers(cluster_name, region, profile, quiet=True):
            log.info("  Confirmed clean.")
            return True
        if time.time() - start >= timeout:
            break
        time.sleep(interval)

    log.error(f"  Not clean after {timeout}s:")
    detect_aws_load_balancers(cluster_name, region, profile, quiet=False)
    force_clear_stuck_finalizers(cluster_name, region, profile)

    force_timeout = 90
    start = time.time()
    while True:
        if detect_aws_load_balancers(cluster_name, region, profile, quiet=True):
            log.info("  Confirmed clean after forced cleanup.")
            return True
        if time.time() - start >= force_timeout:
            break
        time.sleep(interval)

    log.error("Still not clean even after forcing finalizer removal - something is fundamentally wrong:")
    detect_aws_load_balancers(cluster_name, region, profile, quiet=False)
    return False


def detect_aws_load_balancers(cluster_name: str, region: str, profile: str, quiet: bool) -> bool:
    remaining: list[str] = []

    for entry in find_alb_ingresses():
        remaining.append(f"Ingress: {entry}")
    for entry in find_aws_lb_services():
        remaining.append(f"Service: {entry}")

    if api_group_installed("gateway.networking.k8s.io"):
        for kind in GATEWAY_API_KINDS:
            for entry in list_all_of_kind(kind):
                remaining.append(f"{kind}: {entry}")
    for kind in LBC_CONFIG_KINDS:
        if api_group_installed("gateway.k8s.aws"):
            for entry in list_all_of_kind(kind):
                remaining.append(f"{kind}: {entry}")
    for kind in ELBV2_KINDS:
        if api_group_installed("elbv2.k8s.aws"):
            for entry in list_all_of_kind(kind):
                remaining.append(f"{kind}: {entry}")
    for kind in AGA_KINDS:
        if api_group_installed("aga.k8s.aws"):
            for entry in list_all_of_kind(kind):
                remaining.append(f"{kind}: {entry}")

    # Authoritative AWS-side check, independent of walking Kubernetes
    # objects: any load balancer tagged as owned by this cluster is in
    # scope, regardless of whether we can still find the Kubernetes
    # object that created it.
    lb_arns = run.run(
        ["aws", "elbv2", "describe-load-balancers", "--region", region, "--profile", profile,
         "--query", "LoadBalancers[].LoadBalancerArn", "--output", "text"],
        check=False,
    )
    if lb_arns:
        arns = lb_arns.split()
        for i in range(0, len(arns), 20):
            chunk = arns[i : i + 20]
            owned = run.run(
                ["aws", "elbv2", "describe-tags", "--region", region, "--profile", profile,
                 "--resource-arns", *chunk,
                 "--query", f"TagDescriptions[?Tags[?Key=='elbv2.k8s.aws/cluster' && Value=='{cluster_name}']].ResourceArn",
                 "--output", "text"],
                check=False,
            )
            for arn in owned.split():
                remaining.append(f"AWS LoadBalancer: {arn}")

    if remaining:
        if not quiet:
            log.error(f"{len(remaining)} resource(s) that provision or reference an AWS load balancer are still present:")
            for entry in remaining:
                print(f"     {entry}", file=sys.stderr)
        return False
    return True


def force_clear_stuck_finalizers(cluster_name: str, region: str, profile: str) -> None:
    log.warn("Forcing finalizer removal on stuck resources. This may leave AWS-side")
    log.warn("resources (ALB/NLB/target groups/security groups) orphaned if the")
    log.warn("controller hadn't actually finished deprovisioning them yet.")

    for kind in [*GATEWAY_API_KINDS, *LBC_CONFIG_KINDS, *ELBV2_KINDS, *AGA_KINDS]:
        for entry in list_all_of_kind(kind):
            if "/" in entry:
                ns, name = entry.split("/", 1)
                log.info(f"  Stripping finalizers: {kind} {entry}")
                run.run(["kubectl", "patch", kind, name, "-n", ns, "--type=merge", "-p", '{"metadata":{"finalizers":null}}'], check=False)
            else:
                log.info(f"  Stripping finalizers: {kind} {entry}")
                run.run(["kubectl", "patch", kind, entry, "--type=merge", "-p", '{"metadata":{"finalizers":null}}'], check=False)

    for entry in find_alb_ingresses():
        ns, name = entry.split("/", 1)
        log.info(f"  Stripping finalizers: ingress {entry}")
        run.run(["kubectl", "patch", "ingress", name, "-n", ns, "--type=merge", "-p", '{"metadata":{"finalizers":null}}'], check=False)

    for entry in find_aws_lb_services():
        ns, name = entry.split("/", 1)
        log.info(f"  Stripping finalizers: service {entry}")
        run.run(["kubectl", "patch", "svc", name, "-n", ns, "--type=merge", "-p", '{"metadata":{"finalizers":null}}'], check=False)

    force_delete_orphaned_load_balancers(cluster_name, region, profile)


def force_delete_orphaned_load_balancers(cluster_name: str, region: str, profile: str) -> None:
    lb_arns = run.run(
        ["aws", "elbv2", "describe-load-balancers", "--region", region, "--profile", profile,
         "--query", "LoadBalancers[].LoadBalancerArn", "--output", "text"],
        check=False,
    )
    for arn in lb_arns.split():
        owned = run.run(
            ["aws", "elbv2", "describe-tags", "--region", region, "--profile", profile, "--resource-arns", arn,
             "--query", "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster' && Value=='" + cluster_name + "'] | length(@)",
             "--output", "text"],
            check=False,
        )
        if owned in ("0", ""):
            continue

        log.info(f"  Deleting orphaned AWS load balancer: {arn}")
        tg_arns = run.run(
            ["aws", "elbv2", "describe-target-groups", "--region", region, "--profile", profile,
             "--load-balancer-arn", arn, "--query", "TargetGroups[].TargetGroupArn", "--output", "text"],
            check=False,
        )
        run.run(["aws", "elbv2", "delete-load-balancer", "--region", region, "--profile", profile, "--load-balancer-arn", arn], check=False)

        for tg_arn in tg_arns.split():
            log.info(f"  Deleting orphaned target group: {tg_arn}")
            elapsed = 0
            while not run.run_ok(["aws", "elbv2", "delete-target-group", "--region", region, "--profile", profile, "--target-group-arn", tg_arn]):
                if elapsed >= 30:
                    log.warn(f"  Could not delete target group {tg_arn} after 30s - leaving it behind.")
                    break
                time.sleep(5)
                elapsed += 5


# ── Helm / CRDs ──────────────────────────────────────────────────────────


def uninstall_lbc_helm_chart() -> None:
    log.section("Removing AWS Load Balancer Controller Helm release...")
    if run.run_ok(["helm", "status", "aws-load-balancer-controller", "--namespace", "kube-system"]):
        run.run_streamed(["helm", "uninstall", "aws-load-balancer-controller", "--namespace", "kube-system"])
    else:
        log.info("  Helm release not found, skipping.")


def uninstall_gateway_crds() -> None:
    log.section("Deleting Gateway API + controller core CRDs...")
    for url in CRD_MANIFEST_URLS:
        run.run(["kubectl", "delete", "--filename", url, "--ignore-not-found=true"], check=False)


# ── IAM / auth teardown ──────────────────────────────────────────────────


def determine_auth_mode() -> str:
    log.section(f"Determining IAM binding type for ServiceAccount {SA_NAMESPACE}/{SERVICE_ACCOUNT_NAME}...")

    role_arn = run.run(
        ["kubectl", "get", "sa", SERVICE_ACCOUNT_NAME, "-n", SA_NAMESPACE,
         "-o", r"jsonpath={.metadata.annotations.eks\.amazonaws\.com/role-arn}"],
        check=False,
    )
    if role_arn:
        log.info("  ServiceAccount is annotated with an IAM role -> IRSA.")
        return "irsa"

    return ""  # Pod Identity vs. "nothing" is disambiguated per-caller (needs cluster/region/profile)


def find_pod_identity_association(cluster_name: str, region: str, profile: str) -> str:
    return run.run(
        ["aws", "eks", "list-pod-identity-associations", "--cluster-name", cluster_name, "--region", region,
         "--profile", profile, "--namespace", SA_NAMESPACE, "--service-account", SERVICE_ACCOUNT_NAME,
         "--query", "associations[0].associationId", "--output", "text"],
        check=False,
    )


def cfn_stack_exists(stack_name: str, region: str, profile: str) -> bool:
    return run.run_ok(["aws", "cloudformation", "describe-stacks", "--stack-name", stack_name, "--region", region, "--profile", profile])


def delete_cfn_stack(stack_name: str, region: str, profile: str) -> None:
    log.section(f"Deleting CloudFormation stack: {stack_name}...")
    protection = run.run(
        ["aws", "cloudformation", "describe-stacks", "--stack-name", stack_name, "--region", region, "--profile", profile,
         "--query", "Stacks[0].EnableTerminationProtection", "--output", "text"],
        check=False,
    )
    if protection == "True":
        log.info("  Termination protection is enabled on this stack - disabling it first...")
        run.run(["aws", "cloudformation", "update-termination-protection", "--stack-name", stack_name,
                  "--region", region, "--profile", profile, "--no-enable-termination-protection"])

    run.run(["aws", "cloudformation", "delete-stack", "--stack-name", stack_name, "--region", region, "--profile", profile])
    log.info("  Waiting for stack deletion...")
    run.run(["aws", "cloudformation", "wait", "stack-delete-complete", "--stack-name", stack_name, "--region", region, "--profile", profile])
    log.info("  Stack deleted.")


def delete_service_account() -> None:
    log.section(f"Deleting ServiceAccount {SA_NAMESPACE}/{SERVICE_ACCOUNT_NAME}...")
    run.run(["kubectl", "delete", "sa", SERVICE_ACCOUNT_NAME, "-n", SA_NAMESPACE, "--ignore-not-found=true"], check=False)


def extract_iam_role_from_sa() -> str:
    role_arn = run.run(
        ["kubectl", "get", "sa", SERVICE_ACCOUNT_NAME, "-n", SA_NAMESPACE,
         "-o", r"jsonpath={.metadata.annotations.eks\.amazonaws\.com/role-arn}"],
        check=False,
    )
    return role_arn.rsplit("/", 1)[-1] if role_arn else ""


def extract_iam_role_from_pod_identity(cluster_name: str, region: str, profile: str) -> tuple[str, str]:
    """Returns (association_id, role_name), either possibly empty."""
    assoc_id = find_pod_identity_association(cluster_name, region, profile)
    if not assoc_id or assoc_id == "None":
        return "", ""
    role_arn = run.run(
        ["aws", "eks", "describe-pod-identity-association", "--cluster-name", cluster_name, "--region", region,
         "--profile", profile, "--association-id", assoc_id, "--query", "association.roleArn", "--output", "text"],
        check=False,
    )
    role_name = role_arn.rsplit("/", 1)[-1] if role_arn and role_arn != "None" else ""
    return assoc_id, role_name


def delete_pod_identity_association(cluster_name: str, region: str, profile: str, association_id: str) -> None:
    if not association_id:
        log.section("No Pod Identity association to delete, skipping.")
        return
    log.section(f"Deleting Pod Identity association: {association_id}...")
    run.run(["aws", "eks", "delete-pod-identity-association", "--cluster-name", cluster_name, "--region", region,
              "--profile", profile, "--association-id", association_id])
    log.info("  Pod Identity association deleted.")


def delete_iam_role(role_name: str, profile: str) -> None:
    if not role_name:
        log.section("No IAM role to delete, skipping.")
        return
    log.section(f"Deleting IAM Role: {role_name}...")

    if not run.run_ok(["aws", "iam", "get-role", "--role-name", role_name, "--profile", profile]):
        log.info("  IAM Role not found, skipping.")
        return

    policies = run.run(["aws", "iam", "list-attached-role-policies", "--role-name", role_name, "--profile", profile,
                          "--query", "AttachedPolicies[].PolicyArn", "--output", "text"], check=False)
    for policy_arn in policies.split():
        log.info(f"  Detaching policy: {policy_arn}")
        run.run(["aws", "iam", "detach-role-policy", "--role-name", role_name, "--policy-arn", policy_arn, "--profile", profile])

    inline = run.run(["aws", "iam", "list-role-policies", "--role-name", role_name, "--profile", profile,
                        "--query", "PolicyNames[]", "--output", "text"], check=False)
    for policy_name in inline.split():
        log.info(f"  Deleting inline policy: {policy_name}")
        run.run(["aws", "iam", "delete-role-policy", "--role-name", role_name, "--policy-name", policy_name, "--profile", profile])

    profiles = run.run(["aws", "iam", "list-instance-profiles-for-role", "--role-name", role_name, "--profile", profile,
                          "--query", "InstanceProfiles[].InstanceProfileName", "--output", "text"], check=False)
    for profile_name in profiles.split():
        log.info(f"  Removing role from instance profile: {profile_name}")
        run.run(["aws", "iam", "remove-role-from-instance-profile", "--role-name", role_name,
                  "--instance-profile-name", profile_name, "--profile", profile])

    run.run(["aws", "iam", "delete-role", "--role-name", role_name, "--profile", profile])
    log.info("  IAM Role deleted.")


def policy_exists(policy_arn: str, profile: str) -> bool:
    return run.run_ok(["aws", "iam", "get-policy", "--policy-arn", policy_arn, "--profile", profile])


def get_policy_tags(policy_arn: str, profile: str) -> dict[str, str]:
    data = run.run_json(["aws", "iam", "list-policy-tags", "--policy-arn", policy_arn, "--profile", profile])
    return {t["Key"]: t["Value"] for t in (data or {}).get("Tags", [])}


def find_owned_policy_arn(account_id: str, cluster_name: str, profile: str) -> str | None:
    """Locates the policy install_aws_lbc.py created for cluster_name.
    Unlike resolve_policy_name() there (which stops at the first candidate
    that's either free or already ours, since it's choosing a name to
    create/reuse), this must check every candidate: install may have
    landed on any attempt if earlier ones collided, and uninstall has no
    record of which one it picked - only the ownership tag says so.
    Returns None if no candidate is both present and tagged for this
    cluster (e.g. already deleted, or install never got this far).
    """
    for name in naming.candidate_names(naming.POLICY_NAME_PREFIX, cluster_name, naming.IAM_POLICY_NAME_MAX_LENGTH):
        arn = f"arn:aws:iam::{account_id}:policy/{name}"
        if policy_exists(arn, profile) and get_policy_tags(arn, profile).get(naming.OWNER_TAG_KEY) == cluster_name:
            return arn
    return None


def delete_iam_policy(policy_arn: str | None, profile: str) -> None:
    if not policy_arn:
        log.section("No IAM Policy owned by this cluster found, skipping.")
        return
    log.section(f"Deleting IAM Policy: {policy_arn}...")

    roles = run.run(["aws", "iam", "list-entities-for-policy", "--policy-arn", policy_arn, "--profile", profile,
                       "--query", "PolicyRoles[].RoleName", "--output", "text"], check=False)
    for role in roles.split():
        log.info(f"  Detaching from role: {role}")
        run.run(["aws", "iam", "detach-role-policy", "--role-name", role, "--policy-arn", policy_arn, "--profile", profile])

    users = run.run(["aws", "iam", "list-entities-for-policy", "--policy-arn", policy_arn, "--profile", profile,
                       "--query", "PolicyUsers[].UserName", "--output", "text"], check=False)
    for user in users.split():
        log.info(f"  Detaching from user: {user}")
        run.run(["aws", "iam", "detach-user-policy", "--user-name", user, "--policy-arn", policy_arn, "--profile", profile])

    groups = run.run(["aws", "iam", "list-entities-for-policy", "--policy-arn", policy_arn, "--profile", profile,
                        "--query", "PolicyGroups[].GroupName", "--output", "text"], check=False)
    for group in groups.split():
        log.info(f"  Detaching from group: {group}")
        run.run(["aws", "iam", "detach-group-policy", "--group-name", group, "--policy-arn", policy_arn, "--profile", profile])

    versions = run.run(["aws", "iam", "list-policy-versions", "--policy-arn", policy_arn, "--profile", profile,
                          "--query", "Versions[?IsDefaultVersion==`false`].VersionId", "--output", "text"], check=False)
    for version in versions.split():
        log.info(f"  Deleting policy version: {version}")
        run.run(["aws", "iam", "delete-policy-version", "--policy-arn", policy_arn, "--version-id", version, "--profile", profile])

    run.run(["aws", "iam", "delete-policy", "--policy-arn", policy_arn, "--profile", profile])
    log.info("  IAM Policy deleted.")


def delete_auth_association(cluster_name: str, region: str, profile: str, auth_mode: str) -> None:
    if auth_mode == "irsa":
        stack = f"eksctl-{cluster_name}-addon-iamserviceaccount-{SA_NAMESPACE}-{SERVICE_ACCOUNT_NAME}"
        if cfn_stack_exists(stack, region, profile):
            log.section("ServiceAccount + IAM role are eksctl/CloudFormation-managed.")
            log.section("Deleting via 'eksctl delete iamserviceaccount' (owns the SA, role, and stack together)...")
            rc = run.run_streamed(
                ["eksctl", "delete", "iamserviceaccount", f"--cluster={cluster_name}",
                 f"--name={SERVICE_ACCOUNT_NAME}", f"--namespace={SA_NAMESPACE}", f"--region={region}", "--wait"]
            )
            if rc == 0:
                log.info("  Deleted via eksctl.")
            else:
                log.warn("  eksctl delete failed - falling back to direct CloudFormation stack deletion.")
                delete_service_account()
                if cfn_stack_exists(stack, region, profile):
                    delete_cfn_stack(stack, region, profile)
        else:
            log.section("No eksctl-managed CloudFormation stack found - this binding wasn't created by eksctl.")
            role_name = extract_iam_role_from_sa()
            delete_service_account()
            delete_iam_role(role_name, profile)

    elif auth_mode == "pod-identity":
        # Pod Identity never annotates or otherwise owns the ServiceAccount
        # object (unlike IRSA), so this needs deleting regardless of path.
        delete_service_account()

        stack = f"eksctl-{cluster_name}-podidentityrole-{SA_NAMESPACE}-{SERVICE_ACCOUNT_NAME}"
        if cfn_stack_exists(stack, region, profile):
            log.section("IAM role is eksctl/CloudFormation-managed.")
            log.section("Deleting via 'eksctl delete podidentityassociation' (owns the association and role/stack together)...")
            rc = run.run_streamed(
                ["eksctl", "delete", "podidentityassociation", f"--cluster={cluster_name}",
                 f"--namespace={SA_NAMESPACE}", f"--service-account-name={SERVICE_ACCOUNT_NAME}", f"--region={region}"]
            )
            if rc == 0:
                log.info("  Deleted via eksctl.")
            else:
                log.warn("  eksctl delete failed - falling back to direct CloudFormation stack deletion.")
                assoc_id, role_name = extract_iam_role_from_pod_identity(cluster_name, region, profile)
                delete_pod_identity_association(cluster_name, region, profile, assoc_id)
                if cfn_stack_exists(stack, region, profile):
                    delete_cfn_stack(stack, region, profile)
        else:
            log.section("No eksctl-managed CloudFormation stack found - this binding wasn't created by eksctl.")
            assoc_id, role_name = extract_iam_role_from_pod_identity(cluster_name, region, profile)
            delete_pod_identity_association(cluster_name, region, profile, assoc_id)
            delete_iam_role(role_name, profile)

    else:
        log.section("No IAM binding detected, skipping IAM role/association cleanup.")


def main() -> None:
    verify_python()

    parser = argparse.ArgumentParser(description="Removes the AWS Load Balancer Controller from an existing EKS cluster.")
    parser.parse_args()

    cluster_name = os.environ.get("EKS_CLUSTER_NAME") or die("EKS_CLUSTER_NAME is required")
    region = os.environ.get("EKS_REGION") or die("EKS_REGION is required")
    profile = os.environ.get("AWS_PROFILE") or die("AWS_PROFILE is required")

    account_id = run.run(["aws", "sts", "get-caller-identity", "--profile", profile, "--query", "Account", "--output", "text"])
    # Not naming.policy_name(cluster_name) (attempt-0 only): if install hit
    # a genuine collision it may have escalated to a later candidate, so
    # the policy actually owned by this cluster has to be discovered by
    # its ownership tag, not recomputed - see lib/naming.py and
    # install_aws_lbc.py's resolve_policy_name() for how install picks the
    # name in the first place.
    policy_arn = find_owned_policy_arn(account_id, cluster_name, profile)

    if not deprovision_aws_load_balancers(cluster_name, region, profile):
        die("Aborting: cluster is not in a clean state for CRD/Helm teardown.")

    uninstall_lbc_helm_chart()
    uninstall_gateway_crds()

    auth_mode = determine_auth_mode()
    if not auth_mode:
        assoc_id = find_pod_identity_association(cluster_name, region, profile)
        if assoc_id and assoc_id != "None":
            log.info("  Found an EKS Pod Identity association -> Pod Identity.")
            auth_mode = "pod-identity"
        else:
            log.info("  No IRSA annotation or Pod Identity association found.")

    delete_auth_association(cluster_name, region, profile, auth_mode)
    delete_iam_policy(policy_arn, profile)

    log.ok("Cleanup completed successfully!")


if __name__ == "__main__":
    main()
