"""lib/role_discovery.py — Finds the IAM role (and its attached policy)
bound to a Kubernetes ServiceAccount, regardless of whether the binding was
made via IRSA or EKS Pod Identity. Direct port of
01_cli/scripts/lib/role_discovery.sh.
"""

from __future__ import annotations

from lib.aws import AwsClients, get_pod_identity_role_arn, get_role_attached_policy_arns
from lib.errors import die
from lib.k8s import K8sClient, get_service_account_annotation, service_account_exists


def find_role_arn(
    aws: AwsClients, k8s: K8sClient, cluster_name: str, namespace: str, sa_name: str
) -> str:
    """Tries the IRSA role-arn annotation first (set identically by eksctl,
    the aws-cli install path, and the Terraform module - it's the standard
    EKS Pod Identity Webhook contract, not something each tool invents
    independently), then falls back to an EKS Pod Identity association.
    Exits via die() if neither resolves to a role.
    """
    if not service_account_exists(k8s, sa_name, namespace):
        die(f"ServiceAccount '{sa_name}' not found in namespace '{namespace}'.")

    role_arn = get_service_account_annotation(k8s, sa_name, namespace, "eks.amazonaws.com/role-arn")

    if not role_arn:
        role_arn = get_pod_identity_role_arn(aws, cluster_name, namespace, sa_name)

    if not role_arn:
        die(
            f"ServiceAccount '{sa_name}' is bound to a role via neither an IRSA "
            f"role-arn annotation nor an EKS Pod Identity association in region "
            f"'{aws.region}'."
        )

    return role_arn


def find_attached_policy_arn(aws: AwsClients, role_name: str) -> str:
    """Returns the single IAM policy ARN attached to the role, whatever
    it's named. Dies if zero or more than one policy is attached - in the
    more-than-one case that's ambiguous, so the caller should pass an
    explicit policy name instead of relying on discovery.
    """
    attached = get_role_attached_policy_arns(aws, role_name)

    if len(attached) == 0:
        die(f"No IAM policies are attached to role '{role_name}'.")
    if len(attached) == 1:
        return attached[0]

    joined = ",".join(attached)
    die(
        f"Role '{role_name}' has {len(attached)} policies attached ({joined}) "
        "-- pass --policy-name to pick one explicitly."
    )
