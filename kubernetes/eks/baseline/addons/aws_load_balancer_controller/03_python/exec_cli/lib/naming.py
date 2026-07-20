"""lib/naming.py — Scopes AWS account-global resource names (IAM role,
IAM policy) to the target cluster, and generates fallback candidates for
when the scoped name is already taken by something this installer didn't
create.

IAM role and policy names live in a single namespace shared by the whole
AWS account, unlike Kubernetes objects (already isolated per-cluster by
being on separate API servers). A fixed name like
"AmazonEKSLoadBalancerControllerRole" would have every cluster in the
account fight over the same role - and since installing against an
existing role overwrites its trust policy, and uninstalling deletes the
policy unconditionally, running this against a second cluster would
silently rebind (and later delete) the first cluster's binding.

Scoping every account-global name by cluster name (attempt 0 below) avoids
that in the common case. It doesn't fully solve it, though: a name is not
a reservation. Some unrelated role or policy - created by hand, by another
tool, or left over from a torn-down environment that reused the same
cluster name - can already occupy the exact name this installer would
compute. install_aws_lbc.py's resolve_role_name()/resolve_policy_name()
handle that: they check every existing candidate's ownership tag (see
OWNER_TAG_KEY) before deciding whether to reuse it (this installer's own
prior run against the same cluster - a safe, idempotent re-install) or
skip it as a genuine collision and move on to attempt 1, 2, ... - each a
distinct, deterministic name derived from a short hash, the same idea
eksctl uses when it appends a generated suffix to avoid colliding with an
existing resource instead of failing outright.

Only the aws-cli tool path actually needs this: eksctl generates its own
uniquely-named role via CloudFormation, so it has nothing to collide with.
The policy, however, is shared by both tool paths and always goes through
this escalation.
"""

from __future__ import annotations

import hashlib
import re

IAM_ROLE_NAME_MAX_LENGTH = 64
IAM_POLICY_NAME_MAX_LENGTH = 128

ROLE_NAME_PREFIX = "AmazonEKSLoadBalancerControllerRole"
POLICY_NAME_PREFIX = "AWSLoadBalancerControllerIAMPolicy"

# Set on every role/policy this installer creates, so a later run (this
# cluster's re-install, or a different cluster whose computed name happens
# to collide) can tell "mine, safe to reuse" from "someone/something
# else's, needs a different name" purely by reading a tag - no guessing
# from the name or contents.
OWNER_TAG_KEY = "aws-load-balancer-controller-installer/cluster"

# How many candidate names to try before giving up. Collisions this deep
# would mean 6+ unrelated resources all happen to hash-collide for this
# exact cluster name, which practically never happens - this is a sanity
# ceiling against an infinite loop, not a limit expected to be hit.
MAX_NAME_ATTEMPTS = 6


# IAM role/policy names only allow this character set - anything else (a
# literal "#" from an attempt marker in particular - see candidate_name()
# below) makes the resulting ARN invalid, which the IAM API rejects with
# InvalidInputException rather than the NoSuchEntity a not-found check
# expects, crashing resolve_*_name()/find_owned_policy_arn() instead of
# just treating it as "doesn't exist".
_IAM_NAME_UNSAFE_RE = re.compile(r"[^\w+=,.@-]")


def _hashed_name(prefix: str, display: str, hash_seed: str, max_length: int) -> str:
    """display is what actually appears in the generated name (truncated
    to fit, IAM-safe characters only); hash_seed is only fed to the hash,
    so it's free to contain characters (like "#") that must never end up
    in the name itself - see candidate_name()'s attempt>=1 case.
    """
    suffix = hashlib.sha256(hash_seed.encode()).hexdigest()[:8]
    safe_display = _IAM_NAME_UNSAFE_RE.sub("", display)
    # display usually starts with the cluster name (readable prefix worth
    # keeping if there's room), but isn't guaranteed to - budget against
    # the actual display length, not an assumed structure.
    budget = max_length - len(prefix) - len(suffix) - 2  # two "-" separators
    if budget < 1:
        raise ValueError(
            f"prefix '{prefix}' alone leaves no room for a scoped name "
            f"within {max_length} characters"
        )
    return f"{prefix}-{safe_display[:budget]}-{suffix}"


def candidate_name(prefix: str, cluster_name: str, max_length: int, attempt: int) -> str:
    """Returns the attempt'th deterministic candidate name for (prefix,
    cluster_name). attempt=0 is "<prefix>-<cluster_name>" (or the
    truncated+hashed form if that's too long); attempt>=1 is always a
    hashed form, its suffix seeded by (cluster_name, attempt) so retries
    are reproducible - install and uninstall/re-install always land on the
    same Nth candidate for the same cluster, without needing to persist
    which attempt succeeded anywhere. The attempt marker only ever feeds
    the hash (via hash_seed) - it must never appear in the visible
    display portion of the name, which stays cluster_name alone regardless
    of attempt, or a bare "#1" etc. would make the generated name itself
    IAM-invalid.
    """
    if attempt == 0:
        name = f"{prefix}-{cluster_name}"
        if len(name) <= max_length:
            return name
        return _hashed_name(prefix, cluster_name, cluster_name, max_length)
    return _hashed_name(prefix, cluster_name, f"{cluster_name}#{attempt}", max_length)


def candidate_names(prefix: str, cluster_name: str, max_length: int):
    for attempt in range(MAX_NAME_ATTEMPTS):
        yield candidate_name(prefix, cluster_name, max_length, attempt)


def role_name(cluster_name: str) -> str:
    """The attempt-0 (ideal, no-collision) role name. Only meaningful as a
    fallback display/estimate - the name actually in use for a given
    install is whatever resolve_role_name() in install_aws_lbc.py landed
    on, which this function has no way to know after the fact.
    """
    return candidate_name(ROLE_NAME_PREFIX, cluster_name, IAM_ROLE_NAME_MAX_LENGTH, 0)


def policy_name(cluster_name: str) -> str:
    """The attempt-0 (ideal, no-collision) policy name - see role_name()'s
    docstring for the same caveat.
    """
    return candidate_name(POLICY_NAME_PREFIX, cluster_name, IAM_POLICY_NAME_MAX_LENGTH, 0)
