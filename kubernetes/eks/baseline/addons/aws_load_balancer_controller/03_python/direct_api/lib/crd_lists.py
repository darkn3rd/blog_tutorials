"""lib/crd_lists.py — Shared CRD name lists for Gateway API validation and
cleanup.
"""

from __future__ import annotations

STANDARD_GATEWAY_CRDS = [
    "backendtlspolicies.gateway.networking.k8s.io",
    "gatewayclasses.gateway.networking.k8s.io",
    "gateways.gateway.networking.k8s.io",
    "grpcroutes.gateway.networking.k8s.io",
    "httproutes.gateway.networking.k8s.io",
    "listenersets.gateway.networking.k8s.io",
    "referencegrants.gateway.networking.k8s.io",
    "tlsroutes.gateway.networking.k8s.io",
]

EXPERIMENTAL_GATEWAY_CRDS = [
    "gatewayclasses.gateway.networking.k8s.io",
    "gateways.gateway.networking.k8s.io",
    "grpcroutes.gateway.networking.k8s.io",
    "httproutes.gateway.networking.k8s.io",
    "listenersets.gateway.networking.k8s.io",
    "referencegrants.gateway.networking.k8s.io",
    "tcproutes.gateway.networking.k8s.io",
    "tlsroutes.gateway.networking.k8s.io",
    "udproutes.gateway.networking.k8s.io",
]

AWS_GATEWAY_CRDS = [
    "listenerruleconfigurations.gateway.k8s.aws",
    "loadbalancerconfigurations.gateway.k8s.aws",
    "targetgroupconfigurations.gateway.k8s.aws",
]


def resolve_crds(channel: str, source: str) -> list[str]:
    """Returns the deduplicated CRD list (order preserved) for the given
    combination.

    channel : standard | experimental
    source  : gateway-api | aws-gateway | all
    """
    if channel == "standard":
        channel_crds = STANDARD_GATEWAY_CRDS
    elif channel == "experimental":
        channel_crds = EXPERIMENTAL_GATEWAY_CRDS
    else:
        raise ValueError(f"Unknown channel '{channel}'. Use 'standard' or 'experimental'.")

    if source == "gateway-api":
        pool = channel_crds
    elif source == "aws-gateway":
        pool = AWS_GATEWAY_CRDS
    elif source == "all":
        pool = channel_crds + AWS_GATEWAY_CRDS
    else:
        raise ValueError(f"Unknown source '{source}'. Use 'gateway-api', 'aws-gateway', or 'all'.")

    seen: set[str] = set()
    resolved: list[str] = []
    for crd in pool:
        if crd not in seen:
            seen.add(crd)
            resolved.append(crd)
    return resolved
