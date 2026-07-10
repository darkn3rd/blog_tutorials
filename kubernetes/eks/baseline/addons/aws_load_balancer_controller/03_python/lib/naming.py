"""lib/naming.py — Scopes AWS account-global resource names (IAM role,
IAM policy) to the target cluster.

IAM role and policy names live in a single namespace shared by the whole
AWS account, unlike Kubernetes objects (already isolated per-cluster by
being on separate API servers). A fixed name like
"AmazonEKSLoadBalancerControllerRole" would have every cluster in the
account fight over the same role - and since installing against an
existing role overwrites its trust policy, and uninstalling deletes the
policy unconditionally, running this against a second cluster would
silently rebind (and later delete) the first cluster's binding.

Scoping every account-global name by cluster name avoids that, the same
way eksctl scopes the resources it creates.
"""

from __future__ import annotations

import hashlib

IAM_ROLE_NAME_MAX_LENGTH = 64
IAM_POLICY_NAME_MAX_LENGTH = 128


def scoped_name(prefix: str, cluster_name: str, max_length: int) -> str:
    """Returns "<prefix>-<cluster_name>". If that would exceed max_length,
    truncates the cluster-name portion and appends a short deterministic
    hash of the full cluster name, so two long cluster names that only
    differ after the truncation point still produce distinct, valid names.
    """
    name = f"{prefix}-{cluster_name}"
    if len(name) <= max_length:
        return name

    suffix = hashlib.sha256(cluster_name.encode()).hexdigest()[:8]
    budget = max_length - len(prefix) - len(suffix) - 2  # two "-" separators
    if budget < 1:
        raise ValueError(
            f"prefix '{prefix}' alone leaves no room for a cluster-scoped "
            f"name within {max_length} characters"
        )
    return f"{prefix}-{cluster_name[:budget]}-{suffix}"


def role_name(cluster_name: str) -> str:
    return scoped_name("AmazonEKSLoadBalancerControllerRole", cluster_name, IAM_ROLE_NAME_MAX_LENGTH)


def policy_name(cluster_name: str) -> str:
    return scoped_name("AWSLoadBalancerControllerIAMPolicy", cluster_name, IAM_POLICY_NAME_MAX_LENGTH)
