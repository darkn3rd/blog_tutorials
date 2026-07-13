"""lib/aws.py — Shared boto3 helpers (IAM, EKS, ELBv2, CloudFormation, EC2, STS).

Every AWS call used across the installer, uninstaller, and validation/status
scripts lives here once - e.g. the IAM role detach/delete sequence is one
function used from every place that needs it, rather than being
reimplemented per caller.
"""

from __future__ import annotations

import json
import time
import urllib.request
from dataclasses import dataclass
from typing import Any

import boto3
from botocore.exceptions import ClientError

from lib import naming
from lib.errors import die


@dataclass
class AwsClients:
    """Bundles the boto3 clients every script needs, built once from a
    single Session so AWS_PROFILE/region are threaded through explicitly
    rather than relied on implicitly from process environment.
    """

    session: boto3.Session
    region: str

    @classmethod
    def create(cls, profile: str, region: str) -> "AwsClients":
        session = boto3.Session(profile_name=profile, region_name=region)
        return cls(session=session, region=region)

    @property
    def iam(self):
        return self.session.client("iam")

    @property
    def eks(self):
        return self.session.client("eks", region_name=self.region)

    @property
    def elbv2(self):
        return self.session.client("elbv2", region_name=self.region)

    @property
    def cloudformation(self):
        return self.session.client("cloudformation", region_name=self.region)

    @property
    def ec2(self):
        return self.session.client("ec2", region_name=self.region)

    @property
    def sts(self):
        return self.session.client("sts")


# ── Identity / connectivity ────────────────────────────────────────────────


def verify_aws_connectivity(clients: AwsClients) -> str:
    """Exits via die() if AWS credentials are invalid or unreachable.
    Returns the caller's ARN on success.
    """
    try:
        return clients.sts.get_caller_identity()["Arn"]
    except Exception as exc:  # noqa: BLE001 - surfacing any auth failure verbatim
        die(
            f"AWS authentication failed: {exc}\n"
            "Run 'aws sso login' or check your environment credentials."
        )


def get_account_id(clients: AwsClients) -> str:
    return clients.sts.get_caller_identity()["Account"]


# ── EKS cluster / addon lookups ────────────────────────────────────────────


def describe_cluster(clients: AwsClients, cluster_name: str) -> dict[str, Any]:
    return clients.eks.describe_cluster(name=cluster_name)["cluster"]


def get_cluster_vpc_id(clients: AwsClients, cluster_name: str) -> str:
    return describe_cluster(clients, cluster_name)["resourcesVpcConfig"]["vpcId"]


def get_cluster_oidc_issuer(clients: AwsClients, cluster_name: str) -> str:
    return describe_cluster(clients, cluster_name)["identity"]["oidc"]["issuer"]


def addon_status(clients: AwsClients, cluster_name: str, addon_name: str) -> str | None:
    """Returns the addon's status (e.g. "ACTIVE"), or None if not installed."""
    try:
        resp = clients.eks.describe_addon(clusterName=cluster_name, addonName=addon_name)
        return resp["addon"]["status"]
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ResourceNotFoundException":
            return None
        raise


def addon_service_account_role_arn(
    clients: AwsClients, cluster_name: str, addon_name: str
) -> str | None:
    try:
        resp = clients.eks.describe_addon(clusterName=cluster_name, addonName=addon_name)
        return resp["addon"].get("serviceAccountRoleArn")
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ResourceNotFoundException":
            return None
        raise


# ── OIDC provider ───────────────────────────────────────────────────────────


def oidc_provider_exists(clients: AwsClients, account_id: str, oidc_provider: str) -> bool:
    arn = f"arn:aws:iam::{account_id}:oidc-provider/{oidc_provider}"
    try:
        clients.iam.get_open_id_connect_provider(OpenIDConnectProviderArn=arn)
        return True
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "NoSuchEntity":
            return False
        raise


def oidc_provider_registered_for_issuer(clients: AwsClients, oidc_issuer: str) -> bool:
    """Checks whether there is an IAM OIDC provider whose ARN ends with the
    cluster's OIDC issuer ID, regardless of account.
    """
    oidc_id = oidc_issuer.rstrip("/").rsplit("/", 1)[-1]
    providers = clients.iam.list_open_id_connect_providers()["OpenIDConnectProviderList"]
    return any(p["Arn"].endswith(f"/{oidc_id}") for p in providers)


# ── Pod Identity associations ───────────────────────────────────────────────


def find_pod_identity_association_id(
    clients: AwsClients, cluster_name: str, namespace: str, service_account: str
) -> str | None:
    resp = clients.eks.list_pod_identity_associations(
        clusterName=cluster_name,
        namespace=namespace,
        serviceAccount=service_account,
    )
    associations = resp.get("associations", [])
    return associations[0]["associationId"] if associations else None


def get_pod_identity_role_arn(
    clients: AwsClients, cluster_name: str, namespace: str, service_account: str
) -> str | None:
    """Prints/returns the role ARN of the EKS Pod Identity association for
    the given namespace/ServiceAccount, or None if no association exists.
    """
    association_id = find_pod_identity_association_id(
        clients, cluster_name, namespace, service_account
    )
    if association_id is None:
        return None
    resp = clients.eks.describe_pod_identity_association(
        clusterName=cluster_name, associationId=association_id
    )
    return resp["association"]["roleArn"]


def create_pod_identity_association(
    clients: AwsClients,
    cluster_name: str,
    namespace: str,
    service_account: str,
    role_arn: str,
) -> None:
    clients.eks.create_pod_identity_association(
        clusterName=cluster_name,
        namespace=namespace,
        serviceAccount=service_account,
        roleArn=role_arn,
    )


def delete_pod_identity_association(
    clients: AwsClients, cluster_name: str, association_id: str
) -> None:
    clients.eks.delete_pod_identity_association(
        clusterName=cluster_name, associationId=association_id
    )


# ── IAM policy ──────────────────────────────────────────────────────────────


def policy_exists(clients: AwsClients, policy_arn: str) -> bool:
    try:
        clients.iam.get_policy(PolicyArn=policy_arn)
        return True
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "NoSuchEntity":
            return False
        raise


def fetch_live_policy(clients: AwsClients, policy_arn: str) -> dict[str, Any]:
    """Fetches the default version of a managed IAM policy document."""
    try:
        policy = clients.iam.get_policy(PolicyArn=policy_arn)["Policy"]
    except ClientError:
        die(f"Policy not found or not accessible: {policy_arn}")
    version_id = policy["DefaultVersionId"]
    try:
        version = clients.iam.get_policy_version(
            PolicyArn=policy_arn, VersionId=version_id
        )["PolicyVersion"]
    except ClientError:
        die(f"Could not retrieve policy version {version_id} for: {policy_arn}")
    document = version["Document"]
    # botocore returns an already-decoded dict for JSON policy documents in
    # some versions and a raw string in others depending on how the policy
    # was created - normalise to a dict either way.
    return json.loads(document) if isinstance(document, str) else document


def create_policy(clients: AwsClients, policy_name: str, policy_document: dict[str, Any]) -> str:
    resp = clients.iam.create_policy(
        PolicyName=policy_name, PolicyDocument=json.dumps(policy_document)
    )
    return resp["Policy"]["Arn"]


def get_policy_tags(clients: AwsClients, policy_arn: str) -> dict[str, str]:
    resp = clients.iam.list_policy_tags(PolicyArn=policy_arn)
    return {t["Key"]: t["Value"] for t in resp["Tags"]}


def tag_policy(clients: AwsClients, policy_arn: str, key: str, value: str) -> None:
    clients.iam.tag_policy(PolicyArn=policy_arn, Tags=[{"Key": key, "Value": value}])


def resolve_policy_name(clients: AwsClients, account_id: str, cluster_name: str) -> str:
    """Returns the policy name to use for this cluster: the first
    candidate from lib.naming.candidate_names() that either doesn't exist
    yet, or already exists and is tagged (via lib.naming.OWNER_TAG_KEY) as
    owned by this cluster - a prior run of this same installer against the
    same cluster, safe to reuse idempotently. A candidate that exists but
    isn't tagged for this cluster is a genuine collision with something
    this installer didn't create, and is skipped in favor of the next
    candidate rather than silently reused or overwritten.
    """
    for name in naming.candidate_names(
        naming.POLICY_NAME_PREFIX, cluster_name, naming.IAM_POLICY_NAME_MAX_LENGTH
    ):
        arn = f"arn:aws:iam::{account_id}:policy/{name}"
        if not policy_exists(clients, arn):
            return name
        if get_policy_tags(clients, arn).get(naming.OWNER_TAG_KEY) == cluster_name:
            return name
    die(
        f"Could not find an available or already-owned policy name for cluster "
        f"'{cluster_name}' after {naming.MAX_NAME_ATTEMPTS} attempts - every "
        "candidate name collides with a policy this installer doesn't own."
    )


def find_owned_policy_arn(clients: AwsClients, account_id: str, cluster_name: str) -> str | None:
    """Locates the policy this installer created for cluster_name, for
    uninstall. Unlike resolve_policy_name() (which stops at the first
    candidate that's either free or already ours, since it's choosing a
    name to create/reuse), this must check every candidate: install may
    have landed on any attempt if earlier ones collided, and uninstall has
    no record of which one it picked - only the ownership tag says so.
    Returns None if no candidate is both present and tagged for this
    cluster (e.g. already deleted, or install never got this far).
    """
    for name in naming.candidate_names(
        naming.POLICY_NAME_PREFIX, cluster_name, naming.IAM_POLICY_NAME_MAX_LENGTH
    ):
        arn = f"arn:aws:iam::{account_id}:policy/{name}"
        if policy_exists(clients, arn) and get_policy_tags(clients, arn).get(naming.OWNER_TAG_KEY) == cluster_name:
            return arn
    return None


def fetch_upstream_lbc_iam_policy(version: str = "v2.14.1") -> dict[str, Any]:
    """Fetches the AWS Load Balancer Controller's upstream IAM policy JSON
    and amends it with the Gateway API listener-attribute permissions.
    """
    url = (
        "https://raw.githubusercontent.com/kubernetes-sigs/"
        f"aws-load-balancer-controller/{version}/docs/install/iam_policy.json"
    )
    with urllib.request.urlopen(url) as response:  # noqa: S310 - fixed, non-user-controlled URL
        base_policy = json.loads(response.read())

    base_policy["Statement"].append(
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:ModifyListenerAttributes",
            ],
            "Resource": "*",
        }
    )
    return base_policy


def delete_policy(clients: AwsClients, policy_arn: str) -> None:
    """Detaches the policy from every role/user/group still attached to it,
    deletes every non-default version, then deletes the policy itself.
    """
    entities = clients.iam.list_entities_for_policy(PolicyArn=policy_arn)

    for role in entities.get("PolicyRoles", []):
        clients.iam.detach_role_policy(RoleName=role["RoleName"], PolicyArn=policy_arn)
    for user in entities.get("PolicyUsers", []):
        clients.iam.detach_user_policy(UserName=user["UserName"], PolicyArn=policy_arn)
    for group in entities.get("PolicyGroups", []):
        clients.iam.detach_group_policy(GroupName=group["GroupName"], PolicyArn=policy_arn)

    versions = clients.iam.list_policy_versions(PolicyArn=policy_arn)["Versions"]
    for version in versions:
        if not version["IsDefaultVersion"]:
            clients.iam.delete_policy_version(
                PolicyArn=policy_arn, VersionId=version["VersionId"]
            )

    clients.iam.delete_policy(PolicyArn=policy_arn)


# ── IAM role ────────────────────────────────────────────────────────────────


def role_exists(clients: AwsClients, role_name: str) -> bool:
    try:
        clients.iam.get_role(RoleName=role_name)
        return True
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "NoSuchEntity":
            return False
        raise


def create_or_update_role(
    clients: AwsClients, role_name: str, trust_policy: dict[str, Any]
) -> None:
    document = json.dumps(trust_policy)
    if role_exists(clients, role_name):
        clients.iam.update_assume_role_policy(RoleName=role_name, PolicyDocument=document)
    else:
        clients.iam.create_role(RoleName=role_name, AssumeRolePolicyDocument=document)


def attach_role_policy(clients: AwsClients, role_name: str, policy_arn: str) -> None:
    clients.iam.attach_role_policy(RoleName=role_name, PolicyArn=policy_arn)


def get_role_attached_policy_arns(clients: AwsClients, role_name: str) -> list[str]:
    resp = clients.iam.list_attached_role_policies(RoleName=role_name)
    return [p["PolicyArn"] for p in resp["AttachedPolicies"]]


def get_role_tags(clients: AwsClients, role_name: str) -> dict[str, str]:
    resp = clients.iam.list_role_tags(RoleName=role_name)
    return {t["Key"]: t["Value"] for t in resp["Tags"]}


def tag_role(clients: AwsClients, role_name: str, key: str, value: str) -> None:
    clients.iam.tag_role(RoleName=role_name, Tags=[{"Key": key, "Value": value}])


def resolve_role_name(clients: AwsClients, cluster_name: str) -> str:
    """Returns the role name to use for this cluster - same ownership-tag
    based collision handling as resolve_policy_name() above, just for
    roles instead of policies. Only meaningful when this installer creates
    the role directly (boto3, or exec_cli's aws-cli tool path); when
    eksctl creates it via CloudFormation, CloudFormation already generates
    a unique physical name on its own, so there's nothing for this to do.
    """
    for name in naming.candidate_names(
        naming.ROLE_NAME_PREFIX, cluster_name, naming.IAM_ROLE_NAME_MAX_LENGTH
    ):
        if not role_exists(clients, name):
            return name
        if get_role_tags(clients, name).get(naming.OWNER_TAG_KEY) == cluster_name:
            return name
    die(
        f"Could not find an available or already-owned role name for cluster "
        f"'{cluster_name}' after {naming.MAX_NAME_ATTEMPTS} attempts - every "
        "candidate name collides with a role this installer doesn't own."
    )


def delete_role(clients: AwsClients, role_name: str) -> None:
    """Detaches managed policies, deletes inline policies, removes the role
    from any instance profiles, then deletes the role.
    """
    if not role_exists(clients, role_name):
        return

    for policy_arn in get_role_attached_policy_arns(clients, role_name):
        clients.iam.detach_role_policy(RoleName=role_name, PolicyArn=policy_arn)

    inline_policy_names = clients.iam.list_role_policies(RoleName=role_name)["PolicyNames"]
    for policy_name in inline_policy_names:
        clients.iam.delete_role_policy(RoleName=role_name, PolicyName=policy_name)

    profiles = clients.iam.list_instance_profiles_for_role(RoleName=role_name)[
        "InstanceProfiles"
    ]
    for profile in profiles:
        clients.iam.remove_role_from_instance_profile(
            InstanceProfileName=profile["InstanceProfileName"], RoleName=role_name
        )

    clients.iam.delete_role(RoleName=role_name)


def get_instance_profile_role_name(clients: AwsClients, profile_name: str) -> str | None:
    try:
        resp = clients.iam.get_instance_profile(InstanceProfileName=profile_name)
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "NoSuchEntity":
            return None
        raise
    roles = resp["InstanceProfile"]["Roles"]
    return roles[0]["RoleName"] if roles else None


# ── EC2 (for the node-IAM-role auth fallback path) ─────────────────────────


def instance_profile_arn_for_instance(clients: AwsClients, instance_id: str) -> str | None:
    resp = clients.ec2.describe_instances(InstanceIds=[instance_id])
    reservations = resp.get("Reservations", [])
    if not reservations or not reservations[0]["Instances"]:
        return None
    profile = reservations[0]["Instances"][0].get("IamInstanceProfile")
    return profile["Arn"] if profile else None


def describe_subnets(clients: AwsClients, vpc_id: str) -> list[dict[str, Any]]:
    resp = clients.ec2.describe_subnets(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
    )
    return resp["Subnets"]


# ── ELBv2 (load balancer cleanup) ───────────────────────────────────────────


def describe_load_balancer_arns(clients: AwsClients) -> list[str]:
    resp = clients.elbv2.describe_load_balancers()
    return [lb["LoadBalancerArn"] for lb in resp["LoadBalancers"]]


def load_balancers_owned_by_cluster(clients: AwsClients, cluster_name: str) -> list[str]:
    """Returns the ARNs of every load balancer tagged as owned by this
    cluster, via the elbv2.k8s.aws/cluster tag - the authoritative signal
    for cluster ownership, independent of which Kubernetes objects
    provisioned it. Batched into chunks of 20 ARNs per describe-tags call
    (the API's own limit), since this runs inside a bounded polling loop
    and one call per load balancer would let that loop run for minutes on
    a cluster with many load balancers.
    """
    arns = describe_load_balancer_arns(clients)
    if not arns:
        return []

    owned: list[str] = []
    for i in range(0, len(arns), 20):
        chunk = arns[i : i + 20]
        resp = clients.elbv2.describe_tags(ResourceArns=chunk)
        for description in resp["TagDescriptions"]:
            tags = {t["Key"]: t["Value"] for t in description["Tags"]}
            if tags.get("elbv2.k8s.aws/cluster") == cluster_name:
                owned.append(description["ResourceArn"])
    return owned


def delete_load_balancer_and_target_groups(clients: AwsClients, lb_arn: str) -> None:
    """Deletes a load balancer and its target groups. Target group deletion
    is retried for up to 30s: ALB (not NLB) target groups can still be
    attached to a listener rule for a few seconds after delete-load-balancer
    returns, since that call is asynchronous and the ALB's own
    listener/rule teardown needs to finish propagating first.
    """
    tg_resp = clients.elbv2.describe_target_groups(LoadBalancerArn=lb_arn)
    tg_arns = [tg["TargetGroupArn"] for tg in tg_resp["TargetGroups"]]

    clients.elbv2.delete_load_balancer(LoadBalancerArn=lb_arn)

    for tg_arn in tg_arns:
        elapsed = 0
        while True:
            try:
                clients.elbv2.delete_target_group(TargetGroupArn=tg_arn)
                break
            except ClientError:
                if elapsed >= 30:
                    from lib.log import warn

                    warn(f"Could not delete target group {tg_arn} after 30s - leaving it behind.")
                    break
                time.sleep(5)
                elapsed += 5


# ── CloudFormation (eksctl-owned stacks) ────────────────────────────────────


def cfn_stack_exists(clients: AwsClients, stack_name: str) -> bool:
    try:
        clients.cloudformation.describe_stacks(StackName=stack_name)
        return True
    except ClientError:
        return False


def delete_cfn_stack(clients: AwsClients, stack_name: str) -> None:
    """Deletes a CloudFormation stack by name, disabling termination
    protection first if needed - eksctl enables it by default on stacks it
    creates, and delete-stack fails outright otherwise. Blocks until
    deletion completes via boto3's own waiter.
    """
    stacks = clients.cloudformation.describe_stacks(StackName=stack_name)["Stacks"]
    if stacks and stacks[0].get("EnableTerminationProtection"):
        clients.cloudformation.update_termination_protection(
            StackName=stack_name, EnableTerminationProtection=False
        )

    clients.cloudformation.delete_stack(StackName=stack_name)
    waiter = clients.cloudformation.get_waiter("stack_delete_complete")
    waiter.wait(StackName=stack_name)
