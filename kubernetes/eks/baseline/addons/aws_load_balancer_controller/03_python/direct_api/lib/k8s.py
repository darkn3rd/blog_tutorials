"""lib/k8s.py — Shared Kubernetes client helpers.

uninstall_aws_lbc.py needs generic delete-by-kind across Gateway API/
LBC-config/ELBv2/GlobalAccelerator kinds, ALB Ingress/LB Service detection,
and finalizer stripping. The kubernetes client's DynamicClient supports
resolving a Kind to its API group/version/scope by discovery, without
hardcoding any of them, so that generic capability lives here once and
every kind-specific helper below is a thin wrapper over it - each one
gating on whether the kind's CRD is actually installed before acting on it,
without hand-maintaining API versions per kind.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import yaml
from kubernetes import client as k8s_client
from kubernetes import config as k8s_config
from kubernetes import dynamic
from kubernetes.client import ApiException
from kubernetes.dynamic.exceptions import NotFoundError, ResourceNotFoundError

from lib.errors import die

# Every Gateway API kind uninstall_aws_lbc.py's CRD deletion removes. Since
# the CRDs themselves are deleted wholesale regardless of who owns any given
# instance, every live instance of every one of these kinds is in scope for
# cleanup - there is no such thing as "not ours" here. This intentionally
# does NOT filter by GatewayClass name or controllerName: a live HTTPRoute
# attached to a Gateway named "fido" blocks the httproutes CRD's deletion
# exactly the same as one attached to a Gateway named "aws-alb-gateway".
GATEWAY_API_KINDS = [
    "Gateway",
    "HTTPRoute",
    "GRPCRoute",
    "TCPRoute",
    "TLSRoute",
    "UDPRoute",
    "ReferenceGrant",
    "GatewayClass",
]

# Referenced by Gateways via parametersRef, not owned via ownerReference, so
# deleting the Gateway doesn't clean these up on its own.
LBC_CONFIG_KINDS = [
    "LoadBalancerConfiguration",
    "TargetGroupConfiguration",
    "ListenerRuleConfiguration",
]

# The controller's own core CRDs - bundled directly in the Helm chart, not
# fetched separately the way the Gateway API ones are. TargetGroupBinding in
# particular is created by the controller for every Service/Ingress/Gateway
# it provisions a load balancer for - a live one with a stuck finalizer
# blocks its namespace's deletion the exact same way a stuck Gateway does.
ELBV2_KINDS = ["TargetGroupBinding", "IngressClassParams", "ALBTargetControlConfig"]
AGA_KINDS = ["GlobalAccelerator"]


@dataclass
class K8sClient:
    core_v1: k8s_client.CoreV1Api
    apps_v1: k8s_client.AppsV1Api
    networking_v1: k8s_client.NetworkingV1Api
    apiextensions_v1: k8s_client.ApiextensionsV1Api
    dynamic: dynamic.DynamicClient

    @classmethod
    def create(cls) -> "K8sClient":
        k8s_config.load_kube_config()
        api_client = k8s_client.ApiClient()
        return cls(
            core_v1=k8s_client.CoreV1Api(api_client),
            apps_v1=k8s_client.AppsV1Api(api_client),
            networking_v1=k8s_client.NetworkingV1Api(api_client),
            apiextensions_v1=k8s_client.ApiextensionsV1Api(api_client),
            dynamic=dynamic.DynamicClient(api_client),
        )


# ── Connectivity ─────────────────────────────────────────────────────────


def verify_k8s_connectivity(k8s: K8sClient) -> None:
    """Exits via die() if the cluster is unreachable."""
    try:
        k8s.core_v1.get_api_resources()
    except Exception as exc:  # noqa: BLE001
        die(
            f"Cannot reach the Kubernetes cluster: {exc}\n"
            "Check your KUBECONFIG context and credentials."
        )


def current_context() -> str:
    _, active = k8s_config.list_kube_config_contexts()
    return active["name"]


# ── CRDs ─────────────────────────────────────────────────────────────────


def fetch_installed_crds(k8s: K8sClient) -> set[str]:
    resp = k8s.apiextensions_v1.list_custom_resource_definition()
    return {crd.metadata.name for crd in resp.items}


# ── ServiceAccount ──────────────────────────────────────────────────────


def service_account_exists(k8s: K8sClient, name: str, namespace: str) -> bool:
    try:
        k8s.core_v1.read_namespaced_service_account(name, namespace)
        return True
    except ApiException as exc:
        if exc.status == 404:
            return False
        raise


def get_service_account_annotation(
    k8s: K8sClient, name: str, namespace: str, key: str
) -> str | None:
    try:
        sa = k8s.core_v1.read_namespaced_service_account(name, namespace)
    except ApiException as exc:
        if exc.status == 404:
            return None
        raise
    return (sa.metadata.annotations or {}).get(key)


def apply_service_account(
    k8s: K8sClient, name: str, namespace: str, role_arn: str | None
) -> None:
    """Creates or replaces the controller's ServiceAccount. role_arn set
    annotates it for IRSA; None omits the annotation (Pod Identity doesn't
    annotate the ServiceAccount - the binding lives in EKS, not on the
    object - but Helm is invoked with serviceAccount.create=false, so it
    still needs to exist).
    """
    annotations = {"eks.amazonaws.com/role-arn": role_arn} if role_arn else None
    body = k8s_client.V1ServiceAccount(
        metadata=k8s_client.V1ObjectMeta(
            name=name,
            namespace=namespace,
            labels={
                "app.kubernetes.io/component": "controller",
                "app.kubernetes.io/name": name,
            },
            annotations=annotations,
        )
    )
    if service_account_exists(k8s, name, namespace):
        k8s.core_v1.replace_namespaced_service_account(name, namespace, body)
    else:
        k8s.core_v1.create_namespaced_service_account(namespace, body)


def delete_service_account(k8s: K8sClient, name: str, namespace: str) -> None:
    try:
        k8s.core_v1.delete_namespaced_service_account(name, namespace)
    except ApiException as exc:
        if exc.status != 404:
            raise


# ── Generic kind resolution (DynamicClient) ────────────────────────────────


def resolve_resource(k8s: K8sClient, kind: str):
    """Returns the DynamicClient resource for `kind`, or None if its CRD
    isn't installed, by discovery rather than a hardcoded API group.
    """
    try:
        return k8s.dynamic.resources.get(kind=kind)
    except (ResourceNotFoundError, NotFoundError):
        return None


def list_all_of_kind(k8s: K8sClient, kind: str) -> list[tuple[str | None, str]]:
    """Returns (namespace, name) tuples for every live instance of `kind`
    (namespace is None for cluster-scoped kinds, e.g. GatewayClass). Empty
    list if the kind's CRD isn't installed.
    """
    resource = resolve_resource(k8s, kind)
    if resource is None:
        return []
    items = resource.get().items
    return [(getattr(item.metadata, "namespace", None), item.metadata.name) for item in items]


def delete_all_of_kind(k8s: K8sClient, kind: str, label: str | None = None) -> None:
    """Deletes every live instance of `kind`. Uses Background propagation
    (fire the delete and return immediately) rather than Foreground, which
    blocks per object until its finalizer clears - if the controller is
    already gone that finalizer never clears, hanging forever with no
    timeout. The poll-and-force-clear loop in deprovision_load_balancers()
    is the one place that actually waits, on a bounded timeout - every
    delete call here needs to get out of its way instead of blocking ahead
    of it.
    """
    entries = list_all_of_kind(k8s, kind)
    if not entries:
        return

    from lib.log import info

    info(f"  Deleting all {label or kind}...")
    resource = resolve_resource(k8s, kind)
    assert resource is not None
    for namespace, name in entries:
        try:
            if namespace:
                resource.delete(name=name, namespace=namespace, propagation_policy="Background")
            else:
                resource.delete(name=name, propagation_policy="Background")
        except (ApiException, NotFoundError):
            pass


def patch_remove_finalizers(
    k8s: K8sClient, kind: str, name: str, namespace: str | None
) -> None:
    resource = resolve_resource(k8s, kind)
    if resource is None:
        return
    patch = {"metadata": {"finalizers": None}}
    try:
        if namespace:
            resource.patch(name=name, namespace=namespace, body=patch, content_type="application/merge-patch+json")
        else:
            resource.patch(name=name, body=patch, content_type="application/merge-patch+json")
    except (ApiException, NotFoundError):
        pass


# ── ALB Ingress / LB Service detection ─────────────────────────────────────


def find_alb_ingresses(k8s: K8sClient) -> list[tuple[str, str]]:
    """Returns (namespace, name) for every Ingress that will provision an
    ALB. spec.ingressClassName is matched by IngressClass *controller*
    (ingress.k8s.aws/alb), not by an IngressClass literally named "alb" -
    the IngressClass name is arbitrary.

    The deprecated kubernetes.io/ingress.class annotation is different: it's
    a bare string with no backing object to check controller-ownership
    against, so if no IngressClass exists at all (a real, observed case - a
    demo using only this annotation, no IngressClass object ever created),
    the controller-ownership check above can never match anything and this
    function would go permanently blind to every annotation-only ALB
    Ingress. "alb" is matched directly for this annotation specifically
    because it isn't a user-arbitrary name the way a GatewayClass/
    IngressClass object's name is - it's the fixed literal value AWS LBC's
    own docs specify for this annotation; there's no indirection to
    preserve.
    """
    alb_classes = {
        ic.metadata.name
        for ic in k8s.networking_v1.list_ingress_class().items
        if ic.spec.controller == "ingress.k8s.aws/alb"
    }

    matches: list[tuple[str, str]] = []
    for ingress in k8s.networking_v1.list_ingress_for_all_namespaces().items:
        annotations = ingress.metadata.annotations or {}
        annotation_class = annotations.get("kubernetes.io/ingress.class")
        spec_class = ingress.spec.ingress_class_name if ingress.spec else None

        if (
            (annotation_class is not None and annotation_class in alb_classes)
            or (spec_class is not None and spec_class in alb_classes)
            or annotation_class == "alb"
        ):
            matches.append((ingress.metadata.namespace, ingress.metadata.name))
    return matches


def find_aws_lb_services(k8s: K8sClient) -> list[tuple[str, str]]:
    """Returns (namespace, name) for every Service that will provision an
    NLB. Matched by the fixed annotation values / loadBalancerClass prefix
    the AWS LBC itself recognizes - these are not user-renameable, unlike
    class names.
    """
    matches: list[tuple[str, str]] = []
    for svc in k8s.core_v1.list_service_for_all_namespaces().items:
        if svc.spec.type != "LoadBalancer":
            continue
        annotations = svc.metadata.annotations or {}
        lb_type = annotations.get("service.beta.kubernetes.io/aws-load-balancer-type")
        lb_class = svc.spec.load_balancer_class or ""
        if lb_type in ("nlb", "external", "nlb-ip") or lb_class.startswith("service.k8s.aws/"):
            matches.append((svc.metadata.namespace, svc.metadata.name))
    return matches


def delete_ingress(k8s: K8sClient, name: str, namespace: str) -> None:
    try:
        k8s.networking_v1.delete_namespaced_ingress(
            name, namespace, propagation_policy="Background"
        )
    except ApiException as exc:
        if exc.status != 404:
            raise


def delete_service(k8s: K8sClient, name: str, namespace: str) -> None:
    try:
        k8s.core_v1.delete_namespaced_service(name, namespace, propagation_policy="Background")
    except ApiException as exc:
        if exc.status != 404:
            raise


def patch_remove_ingress_finalizers(k8s: K8sClient, name: str, namespace: str) -> None:
    patch = {"metadata": {"finalizers": None}}
    try:
        k8s.networking_v1.patch_namespaced_ingress(name, namespace, patch)
    except ApiException:
        pass


def patch_remove_service_finalizers(k8s: K8sClient, name: str, namespace: str) -> None:
    patch = {"metadata": {"finalizers": None}}
    try:
        k8s.core_v1.patch_namespaced_service(name, namespace, patch)
    except ApiException:
        pass


# ── Multi-document YAML manifests (CRD bundles) ────────────────────────────


def _load_yaml_documents(text: str) -> list[dict[str, Any]]:
    return [doc for doc in yaml.safe_load_all(text) if doc]


def apply_yaml_manifests(k8s: K8sClient, text: str) -> None:
    """Server-side applies every document in a multi-document YAML manifest
    (a CRD bundle, e.g. the Gateway API install manifests) - the Python
    equivalent of `kubectl apply --server-side --force-conflicts -f <url>`.
    """
    for doc in _load_yaml_documents(text):
        api_version = doc["apiVersion"]
        kind = doc["kind"]
        resource = k8s.dynamic.resources.get(api_version=api_version, kind=kind)
        resource.server_side_apply(
            body=doc,
            name=doc["metadata"]["name"],
            namespace=doc["metadata"].get("namespace"),
            field_manager="aws-load-balancer-controller-python-installer",
            force_conflicts=True,
        )


def delete_yaml_manifests(k8s: K8sClient, text: str) -> None:
    """Deletes every document in a multi-document YAML manifest, ignoring
    already-absent resources - the Python equivalent of
    `kubectl delete --ignore-not-found -f <url>`.
    """
    for doc in _load_yaml_documents(text):
        api_version = doc["apiVersion"]
        kind = doc["kind"]
        try:
            resource = k8s.dynamic.resources.get(api_version=api_version, kind=kind)
        except (ResourceNotFoundError, NotFoundError):
            continue
        try:
            resource.delete(
                name=doc["metadata"]["name"],
                namespace=doc["metadata"].get("namespace"),
            )
        except (ApiException, NotFoundError):
            pass
