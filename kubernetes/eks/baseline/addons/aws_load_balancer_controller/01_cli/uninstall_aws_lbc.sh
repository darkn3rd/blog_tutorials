#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "❌ $*" >&2; exit 1; }
# shellcheck source=scripts/lib/bash_version.sh
source "$SCRIPT_DIR/scripts/lib/bash_version.sh"
verify_bash

# Every line of output gets a UTC timestamp prefix - this script can run for
# several minutes (longer with force-clear/orphaned-LB cleanup), and
# figuring out which step actually took the time by eyeballing unmarked
# output was a repeated pain point.
# Also dedups repeated tool-progress lines (terraform "Still creating...
# [Ns elapsed]" heartbeats, eksctl repeated "waiting for..." lines) so a
# slow apply doesn't spam the terminal, while any genuinely new/changed
# line (a different resource, a different message) always prints
# immediately. Lines from this script itself (==>/status markers) print
# as-is; everything else is indented to show it's from the underlying
# tool, not this script.
_tool_output_filter() {
  local _lf_last="" _lf_last_ts=0
  while IFS= read -r _line; do
    local _lf_now _lf_norm
    _lf_now=$(date +%s)
    _lf_norm="$(printf '%s' "$_line" | sed -E \
      -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T? ?[0-9]{2}:[0-9]{2}:[0-9]{2}Z? *//' \
      -e 's/[0-9]+m[0-9]+s elapsed/Ns elapsed/' \
      -e 's/\[[0-9]+s elapsed\]/[Ns elapsed]/')"
    if [[ "$_lf_norm" == "$_lf_last" ]] && (( _lf_now - _lf_last_ts < 30 )); then
      continue
    fi
    _lf_last="$_lf_norm"; _lf_last_ts="$_lf_now"
    case "$_line" in
      "==>"*|"✅"*|"❌"*|"⚠️"*|"─────"*|"====="*|"")
        printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
      *)
        printf '[%s]     | %s\n' "$(date -u +%H:%M:%S)" "$_line" ;;
    esac
  done
}
exec > >(_tool_output_filter) 2>&1

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query "Account" --output text)"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

PROJ_PREFIX_LBC_URL="https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller"
PROJ_PREFIX_GW_URL="https://github.com/kubernetes-sigs/gateway-api"

# Every CRD manifest this script deletes, fetched from source rather than
# hardcoding resource names by hand - a hand-maintained name list is exactly
# how the elbv2.k8s.aws/aga.k8s.aws CRDs went unnoticed for as long as they
# did (missed 3 of them, then discovered a 4th - globalaccelerators.aga.k8s.aws -
# only by going to find the authoritative source instead of guessing more
# names). The last URL is the Helm chart's own bundled core CRDs
# (TargetGroupBinding/IngressClassParams/ALBTargetControlConfig/
# GlobalAccelerator) - auto-installed by `helm install`, never removed by
# `helm uninstall` (Helm's own deliberate default), and otherwise nothing in
# this script's flow would ever remove them.
K8S_LBC_CRD_MANIFESTS=(
    "$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/standard-install.yaml"
    "$PROJ_PREFIX_GW_URL/releases/download/v1.5.0/experimental-install.yaml"
    "$PROJ_PREFIX_LBC_URL/refs/heads/main/config/crd/gateway/gateway-crds.yaml"
    "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml"
)

SA_NAME="aws-load-balancer-controller"
SA_NAMESPACE="${SA_NAMESPACE:-kube-system}"

# Every Gateway API kind this script's CRD deletion removes. Since the CRDs
# themselves are being deleted wholesale regardless of who owns any given
# instance, every live instance of every one of these kinds is in scope for
# cleanup - there is no such thing as "not ours" here. This intentionally
# does NOT filter by GatewayClass name or controllerName: a live HTTPRoute
# attached to a Gateway named "fido" blocks the httproutes CRD's deletion
# exactly the same as one attached to a Gateway named "aws-alb-gateway".
GATEWAY_API_KINDS=(gateway httproute grpcroute tcproute tlsroute udproute referencegrant gatewayclass)
LBC_CONFIG_KINDS=(loadbalancerconfiguration targetgroupconfiguration listenerruleconfiguration)

# The controller's own core CRDs - bundled directly in the Helm chart (see
# K8S_LBC_CRD_MANIFESTS' last URL), not fetched separately the way the
# Gateway API ones are. TargetGroupBinding in particular is created by the
# controller for EVERY Service/Ingress/Gateway it provisions a load balancer
# for, Gateway API ones included - a live one with a stuck finalizer blocks
# its namespace's deletion the exact same way a stuck Gateway does. These
# were missed entirely until a namespace got stuck deleting with "Some
# resources are remaining: targetgroupbindings.elbv2.k8s.aws" and no
# controller left to clear it. globalaccelerator (aga.k8s.aws - a separate
# API group) was found the same way shortly after, by going to the actual
# upstream CRD bundle instead of continuing to guess names by hand.
ELBV2_KINDS=(targetgroupbinding ingressclassparams albtargetcontrolconfigs)
AGA_KINDS=(globalaccelerator)

# list_all_of_kind <kind> -> stdout, one "namespace/name" per line for
# namespaced kinds or "name" per line for cluster-scoped kinds (e.g.
# gatewayclass). Silent empty output if the kind's CRD isn't installed.
list_all_of_kind() {
  local kind="${1:?kind is required}"
  kubectl get "$kind" --all-namespaces -o json 2>/dev/null \
    | jq -r '.items[]? | if .metadata.namespace then "\(.metadata.namespace)/\(.metadata.name)" else .metadata.name end'
}

# delete_all_of_kind <kind> [label] - deletes every live instance of <kind>,
# printing each as it goes. [label] overrides the kind name in the log line
# (e.g. "ALB Ingress" instead of "ingress").
delete_all_of_kind() {
  local kind="${1:?kind is required}"
  local label="${2:-$kind}"

  # --wait=false: issue the delete (set deletionTimestamp) and return
  # immediately rather than blocking for full removal. kubectl's default
  # --wait=true blocks per object until its finalizer clears - if the
  # controller is already gone (e.g. negative_finalizer_lock.sh's scenario,
  # or any real-world crash mid-teardown), that finalizer never clears and
  # this call hangs forever with no timeout of its own. The poll-and-force-
  # clear loop in deprovision_aws_load_balancers() below is the one place
  # that actually waits for completion, on a bounded timeout - every delete
  # call needs to get out of its way instead of blocking ahead of it.
  if ! kubectl get "$kind" --all-namespaces -o name 2>/dev/null | grep -q .; then
    return 0
  fi
  echo "  Deleting all $label..."
  kubectl delete "$kind" --all --all-namespaces --ignore-not-found=true --wait=false 2>&1 | sed 's/^/    /'
}

# find_alb_ingresses -> stdout, one "namespace/name" per line
# spec.ingressClassName is matched by IngressClass *controller*
# (ingress.k8s.aws/alb), not by an IngressClass literally named "alb" - the
# IngressClass name is arbitrary, same reasoning as GatewayClass below.
#
# The deprecated kubernetes.io/ingress.class annotation is different: it's a
# bare string with no backing object to check controller-ownership against,
# so if no IngressClass exists at all (a real, observed case - a demo using
# only this annotation, no IngressClass object ever created), the
# controller-ownership check above can never match anything and this
# function goes permanently blind to every annotation-only ALB Ingress.
# "alb" is safe to match directly here specifically because it isn't a
# user-arbitrary name the way a GatewayClass/IngressClass object's name is -
# it's the fixed literal value AWS LBC's own docs specify for this
# annotation; there's no indirection to preserve.
find_alb_ingresses() {
  local alb_classes
  alb_classes="$(kubectl get ingressclass -o json 2>/dev/null | jq -r '
    .items[]? | select(.spec.controller == "ingress.k8s.aws/alb") | .metadata.name')"
  local classes_json
  classes_json="$(printf '%s\n' "$alb_classes" | jq -R -s -c 'split("\n") | map(select(length > 0))')"

  kubectl get ingress --all-namespaces -o json 2>/dev/null | jq -r --argjson classes "$classes_json" '
    .items[] |
    select(
      (.metadata.annotations["kubernetes.io/ingress.class"] as $c | $c != null and ($classes | index($c) != null)) or
      (.spec.ingressClassName as $c | $c != null and ($classes | index($c) != null)) or
      (.metadata.annotations["kubernetes.io/ingress.class"] == "alb")
    ) | "\(.metadata.namespace)/\(.metadata.name)"'
}

# find_aws_lb_services -> stdout, one "namespace/name" per line
# Matched by the fixed annotation values / loadBalancerClass prefix the AWS
# LBC itself recognizes - these are not user-renameable, unlike class names.
find_aws_lb_services() {
  kubectl get svc --all-namespaces -o json 2>/dev/null | jq -r '
    .items[] |
    select(
      .spec.type == "LoadBalancer" and (
        (.metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-type"] as $t | $t == "nlb" or $t == "external" or $t == "nlb-ip") or
        ((.spec.loadBalancerClass // "") | startswith("service.k8s.aws/"))
      )
    ) | "\(.metadata.namespace)/\(.metadata.name)"'
}

deprovision_aws_load_balancers() {
  echo "==> Deprovisioning AWS load balancer resources..."

  # --wait=false on every call here - see delete_all_of_kind()'s comment.
  # No backgrounding needed either: with --wait=false each call already
  # returns near-instantly, and backgrounding+wait previously meant one
  # stuck delete (no controller left to clear its finalizer) blocked this
  # entire function forever, including the poll-and-force-clear safety net
  # below that was supposed to catch exactly that case.
  local entry
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    local ns="${entry%%/*}" name="${entry##*/}"
    echo "  Deleting ALB Ingress: $ns/$name"
    kubectl delete ingress "$name" -n "$ns" --ignore-not-found=true --wait=false
  done < <(find_alb_ingresses)

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    local ns="${entry%%/*}" name="${entry##*/}"
    echo "  Deleting LB Service: $ns/$name"
    kubectl delete svc "$name" -n "$ns" --ignore-not-found=true --wait=false
  done < <(find_aws_lb_services)

  # Gateway API - wholesale (see GATEWAY_API_KINDS comment above).
  if kubectl api-resources --api-group=gateway.networking.k8s.io &>/dev/null 2>&1; then
    local kind
    for kind in "${GATEWAY_API_KINDS[@]}"; do
      delete_all_of_kind "$kind"
    done
  fi

  # LoadBalancerConfiguration/TargetGroupConfiguration/ListenerRuleConfiguration -
  # referenced by Gateways via parametersRef, not owned via ownerReference, so
  # deleting the Gateway above doesn't clean these up on its own.
  for kind in "${LBC_CONFIG_KINDS[@]}"; do
    if kubectl api-resources --api-group=gateway.k8s.aws 2>/dev/null | grep -qi "^${kind}"; then
      delete_all_of_kind "$kind"
    fi
  done

  # TargetGroupBinding/IngressClassParams/ALBTargetControlConfig (see
  # ELBV2_KINDS comment above) - created directly by the controller, not
  # owned via ownerReference by anything deleted above.
  for kind in "${ELBV2_KINDS[@]}"; do
    if kubectl api-resources --api-group=elbv2.k8s.aws 2>/dev/null | grep -qi "^${kind}"; then
      delete_all_of_kind "$kind"
    fi
  done
  for kind in "${AGA_KINDS[@]}"; do
    if kubectl api-resources --api-group=aga.k8s.aws 2>/dev/null | grep -qi "^${kind}"; then
      delete_all_of_kind "$kind"
    fi
  done

  # Poll rather than blindly sleep-and-hope: finalizer removal happens
  # asynchronously as the controller reconciles each deletion, so give it
  # real time and confirm rather than assuming 30s was enough.
  #
  # Elapsed is measured by wall-clock timestamp, not by incrementing a
  # counter by $interval each loop - detect_aws_load_balancers() itself
  # takes real time to run (several kubectl/aws calls), and a counter that
  # only accounts for the sleep would let the loop's actual wall-clock
  # duration run well past the nominal timeout without ever noticing.
  echo "  Waiting for load balancers to deprovision..."
  local interval=10 timeout=120
  local start_ts elapsed
  start_ts=$(date +%s)
  while true; do
    if detect_aws_load_balancers >/dev/null 2>&1; then
      echo "  Confirmed clean."
      return 0
    fi
    elapsed=$(( $(date +%s) - start_ts ))
    (( elapsed >= timeout )) && break
    sleep "$interval"
  done

  echo "  Not clean after ${timeout}s:" >&2
  detect_aws_load_balancers || true
  force_clear_stuck_finalizers

  # A second bounded poll, not a flat sleep: force_clear_stuck_finalizers()
  # now also issues real aws elbv2 delete-load-balancer/delete-target-group
  # calls, which are asynchronous - a load balancer sits in "deleting" state
  # for a while rather than disappearing instantly, so detect_aws_load_balancers()
  # would still (correctly) see it as present for a bit even though nothing
  # is actually stuck anymore.
  local force_timeout=90
  start_ts=$(date +%s)
  while true; do
    if detect_aws_load_balancers >/dev/null 2>&1; then
      echo "  Confirmed clean after forced cleanup."
      return 0
    fi
    elapsed=$(( $(date +%s) - start_ts ))
    (( elapsed >= force_timeout )) && break
    sleep "$interval"
  done

  echo "❌ Still not clean even after forcing finalizer removal - something is fundamentally wrong:" >&2
  detect_aws_load_balancers
  return 1
}

# detect_aws_load_balancers
# Sanity check: confirms nothing that would provision, reference, or block
# deletion of an AWS load balancer remains. Silent and returns 0 if clean.
# On failure, prints exactly what's left (kind + namespace/name) to stderr
# and returns 1. Callers must treat a non-zero return as fatal: deleting the
# Gateway API CRDs or uninstalling the Helm release while this reports
# uncleared resources will cascade onto them and hang, since the controller
# either won't exist (post-Helm-uninstall) or can't act (mid-CRD-deletion).
detect_aws_load_balancers() {
  local -a remaining=()
  local entry

  # This function is called repeatedly in bounded polling loops (up to ~20
  # times across deprovision_aws_load_balancers()'s two polls) - every call
  # here is multiplied by that, so batching matters. One kubectl get across
  # all Gateway API kinds instead of 8 separate calls, one across whichever
  # LBC config kinds are actually installed instead of 3, one describe-tags
  # across every load balancer instead of one per LB (up to 20 ARNs/call).
  # The original one-call-per-kind/per-LB version was correct but expensive
  # enough (~15+ AWS/kubectl round trips per invocation) that the poll loops
  # alone could run past both this script's own and the negative test
  # suite's timeout without anything actually being stuck.

  while IFS= read -r entry; do
    [[ -n "$entry" ]] && remaining+=("Ingress: $entry")
  done < <(find_alb_ingresses)

  while IFS= read -r entry; do
    [[ -n "$entry" ]] && remaining+=("Service: $entry")
  done < <(find_aws_lb_services)

  if kubectl api-resources --api-group=gateway.networking.k8s.io &>/dev/null 2>&1; then
    local gw_kinds_csv
    gw_kinds_csv="$(IFS=,; echo "${GATEWAY_API_KINDS[*]}")"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && remaining+=("$entry")
    done < <(kubectl get "$gw_kinds_csv" --all-namespaces -o json 2>/dev/null | jq -r '
      .items[]? | "\(.kind | ascii_downcase): " + (if .metadata.namespace then "\(.metadata.namespace)/\(.metadata.name)" else .metadata.name end)')
  fi

  local api_resources_gw
  local -a present_lbc_kinds=()
  api_resources_gw="$(kubectl api-resources --api-group=gateway.k8s.aws 2>/dev/null)"
  local kind
  for kind in "${LBC_CONFIG_KINDS[@]}"; do
    echo "$api_resources_gw" | grep -qi "^${kind}" && present_lbc_kinds+=("$kind")
  done
  if [[ ${#present_lbc_kinds[@]} -gt 0 ]]; then
    local lbc_kinds_csv
    lbc_kinds_csv="$(IFS=,; echo "${present_lbc_kinds[*]}")"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && remaining+=("$entry")
    done < <(kubectl get "$lbc_kinds_csv" --all-namespaces -o json 2>/dev/null | jq -r '
      .items[]? | "\(.kind | ascii_downcase): " + (if .metadata.namespace then "\(.metadata.namespace)/\(.metadata.name)" else .metadata.name end)')
  fi

  local api_resources_elbv2
  local -a present_elbv2_kinds=()
  api_resources_elbv2="$(kubectl api-resources --api-group=elbv2.k8s.aws 2>/dev/null)"
  for kind in "${ELBV2_KINDS[@]}"; do
    echo "$api_resources_elbv2" | grep -qi "^${kind}" && present_elbv2_kinds+=("$kind")
  done
  if [[ ${#present_elbv2_kinds[@]} -gt 0 ]]; then
    local elbv2_kinds_csv
    elbv2_kinds_csv="$(IFS=,; echo "${present_elbv2_kinds[*]}")"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && remaining+=("$entry")
    done < <(kubectl get "$elbv2_kinds_csv" --all-namespaces -o json 2>/dev/null | jq -r '
      .items[]? | "\(.kind | ascii_downcase): " + (if .metadata.namespace then "\(.metadata.namespace)/\(.metadata.name)" else .metadata.name end)')
  fi

  local api_resources_aga
  local -a present_aga_kinds=()
  api_resources_aga="$(kubectl api-resources --api-group=aga.k8s.aws 2>/dev/null)"
  for kind in "${AGA_KINDS[@]}"; do
    echo "$api_resources_aga" | grep -qi "^${kind}" && present_aga_kinds+=("$kind")
  done
  if [[ ${#present_aga_kinds[@]} -gt 0 ]]; then
    local aga_kinds_csv
    aga_kinds_csv="$(IFS=,; echo "${present_aga_kinds[*]}")"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && remaining+=("$entry")
    done < <(kubectl get "$aga_kinds_csv" --all-namespaces -o json 2>/dev/null | jq -r '
      .items[]? | "\(.kind | ascii_downcase): " + (if .metadata.namespace then "\(.metadata.namespace)/\(.metadata.name)" else .metadata.name end)')
  fi

  # Authoritative AWS-side check, independent of walking Kubernetes objects:
  # any load balancer tagged as owned by this cluster is in scope, regardless
  # of whether we can still find (or ever knew to look for) the Kubernetes
  # object that created it. This is what actually answers "did we get
  # everything" - the kubectl-side scan above is best-effort by resource
  # kind, this is ground truth by cluster ownership tag.
  local lb_arns
  lb_arns="$(aws elbv2 describe-load-balancers --region "$EKS_REGION" \
    --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null || true)"
  if [[ -n "$lb_arns" ]]; then
    local owned_arns
    owned_arns="$(aws elbv2 describe-tags --region "$EKS_REGION" --resource-arns $lb_arns \
      --query "TagDescriptions[?Tags[?Key=='elbv2.k8s.aws/cluster' && Value=='${EKS_CLUSTER_NAME}']].ResourceArn" \
      --output text 2>/dev/null || true)"
    local arn
    for arn in $owned_arns; do
      remaining+=("AWS LoadBalancer: $arn")
    done
  fi

  if [[ ${#remaining[@]} -gt 0 ]]; then
    echo "❌ ${#remaining[@]} resource(s) that provision or reference an AWS load balancer are still present:" >&2
    printf '     %s\n' "${remaining[@]}" >&2
    echo "  Refusing to delete Gateway API CRDs or uninstall the Helm release while these exist -" >&2
    echo "  both would cascade onto these objects and hang. Investigate (stuck finalizer? controller" >&2
    echo "  error? a resource this script doesn't know to look for?) and re-run." >&2
    return 1
  fi

  return 0
}

# force_clear_stuck_finalizers
# Last resort, called only after deprovision_aws_load_balancers()'s own
# timeout has already given the controller a full window to reconcile
# deletions properly. Anything still stuck at that point (deletionTimestamp
# set, finalizer present) is not going to clear on its own - the controller
# either already deprovisioned the AWS side and just failed to remove the
# finalizer, or is stuck/gone. Stripping the finalizer trades a possible
# leaked AWS resource for a script that terminates instead of hanging
# forever; the caller re-checks detect_aws_load_balancers() (including its
# AWS-side tag check) immediately after so a real leak is still reported,
# not silently swallowed.
force_clear_stuck_finalizers() {
  echo "⚠️  Forcing finalizer removal on stuck resources. This may leave AWS-side" >&2
  echo "   resources (ALB/NLB/target groups/security groups) orphaned if the" >&2
  echo "   controller hadn't actually finished deprovisioning them yet." >&2

  local kind entry ns name
  for kind in "${GATEWAY_API_KINDS[@]}" "${LBC_CONFIG_KINDS[@]}" "${ELBV2_KINDS[@]}" "${AGA_KINDS[@]}"; do
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      if [[ "$entry" == */* ]]; then
        ns="${entry%%/*}"; name="${entry##*/}"
        echo "  Stripping finalizers: $kind $ns/$name"
        kubectl patch "$kind" "$name" -n "$ns" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
      else
        echo "  Stripping finalizers: $kind $entry"
        kubectl patch "$kind" "$entry" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
      fi
    done < <(list_all_of_kind "$kind")
  done

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    ns="${entry%%/*}"; name="${entry##*/}"
    echo "  Stripping finalizers: ingress $ns/$name"
    kubectl patch ingress "$name" -n "$ns" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
  done < <(find_alb_ingresses)

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    ns="${entry%%/*}"; name="${entry##*/}"
    echo "  Stripping finalizers: service $ns/$name"
    kubectl patch svc "$name" -n "$ns" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
  done < <(find_aws_lb_services)

  force_delete_orphaned_load_balancers
}

# force_delete_orphaned_load_balancers
# Stripping Kubernetes finalizers above only clears the Kubernetes-side
# bookkeeping - it does nothing to the real AWS load balancer if the
# controller was killed before it ever got to deprovision it (e.g. a
# fully-provisioned demo whose controller was force-removed mid-test). Those
# are real, billed AWS resources that nothing else will ever clean up, so
# this deletes any load balancer + its target groups still tagged as owned
# by this cluster, using the exact same ownership tag detect_aws_load_balancers()
# checks - never touches a load balancer that isn't tagged for this cluster.
force_delete_orphaned_load_balancers() {
  local lb_arns
  lb_arns="$(aws elbv2 describe-load-balancers --region "$EKS_REGION" \
    --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null || true)"

  local arn
  for arn in $lb_arns; do
    local owned
    owned="$(aws elbv2 describe-tags --region "$EKS_REGION" --resource-arns "$arn" \
      --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster' && Value=='${EKS_CLUSTER_NAME}'] | length(@)" \
      --output text 2>/dev/null || echo 0)"
    [[ "$owned" == "0" ]] && continue

    echo "  Deleting orphaned AWS load balancer: $arn"
    local tg_arns
    tg_arns="$(aws elbv2 describe-target-groups --region "$EKS_REGION" --load-balancer-arn "$arn" \
      --query 'TargetGroups[].TargetGroupArn' --output text 2>/dev/null || true)"

    aws elbv2 delete-load-balancer --region "$EKS_REGION" --load-balancer-arn "$arn" 2>/dev/null || true

    local tg_arn
    for tg_arn in $tg_arns; do
      echo "  Deleting orphaned target group: $tg_arn"
      # ALB (not NLB) target groups can still be attached to a listener rule
      # for a few seconds after delete-load-balancer returns - that call is
      # asynchronous, and the ALB's own listener/rule teardown needs to
      # finish propagating before its target groups become deletable. Retry
      # briefly instead of silently leaving them behind.
      local tg_elapsed=0
      until aws elbv2 delete-target-group --region "$EKS_REGION" --target-group-arn "$tg_arn" 2>/dev/null; do
        (( tg_elapsed >= 30 )) && { echo "  ⚠️  Could not delete target group $tg_arn after 30s - leaving it behind." >&2; break; }
        sleep 5
        tg_elapsed=$((tg_elapsed + 5))
      done
    done
  done
}

uninstall_lbc_helm_chart() {
  echo "==> Removing AWS Load Balancer Controller Helm release..."
  if helm status aws-load-balancer-controller --namespace kube-system &>/dev/null; then
    helm uninstall aws-load-balancer-controller --namespace kube-system
  else
    echo "  Helm release not found, skipping."
  fi
}

uninstall_gateway_crds() {
  echo "==> Deleting Gateway API + controller core CRDs..."
  for url in "${K8S_LBC_CRD_MANIFESTS[@]}"; do
    kubectl delete --filename "$url" --ignore-not-found=true 2>/dev/null || true
  done
}

determine_auth_mode() {
  echo "==> Determining IAM binding type for ServiceAccount $SA_NAMESPACE/$SA_NAME..."

  local sa_role_arn
  sa_role_arn="$(kubectl get sa "$SA_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || true)"

  if [[ -n "$sa_role_arn" ]]; then
    echo "  ServiceAccount is annotated with an IAM role -> IRSA."
    AUTH_MODE="irsa"
    return 0
  fi

  # No annotation doesn't necessarily mean Pod Identity - verify a live
  # association actually exists rather than assuming.
  local assoc_id
  assoc_id="$(aws eks list-pod-identity-associations \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --namespace "$SA_NAMESPACE" \
    --service-account "$SA_NAME" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null || true)"

  if [[ -n "$assoc_id" && "$assoc_id" != "None" ]]; then
    echo "  Found an EKS Pod Identity association -> Pod Identity."
    AUTH_MODE="pod-identity"
    return 0
  fi

  echo "  No IRSA annotation or Pod Identity association found."
  AUTH_MODE=""
}

extract_iam_role_from_sa() {
  echo "==> Extracting IAM role from ServiceAccount annotation..."
  IAM_ROLE_ARN="$(kubectl get sa "$SA_NAME" -n "$SA_NAMESPACE" \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || true)"
  if [[ -n "$IAM_ROLE_ARN" ]]; then
    IAM_ROLE_NAME="${IAM_ROLE_ARN##*/}"
    echo "  Found IAM role: $IAM_ROLE_NAME"
  else
    echo "  No IAM role annotation found on ServiceAccount."
    IAM_ROLE_NAME=""
  fi
}

extract_iam_role_from_pod_identity() {
  echo "==> Extracting IAM role from Pod Identity association..."

  local assoc_id
  assoc_id="$(aws eks list-pod-identity-associations \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --namespace "$SA_NAMESPACE" \
    --service-account "$SA_NAME" \
    --query "associations[0].associationId" \
    --output text 2>/dev/null || true)"

  if [[ -z "$assoc_id" || "$assoc_id" == "None" ]]; then
    echo "  No Pod Identity association found."
    POD_IDENTITY_ASSOCIATION_ID=""
    IAM_ROLE_NAME=""
    return 0
  fi

  POD_IDENTITY_ASSOCIATION_ID="$assoc_id"

  local role_arn
  role_arn="$(aws eks describe-pod-identity-association \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --association-id "$assoc_id" \
    --query "association.roleArn" \
    --output text 2>/dev/null || true)"

  if [[ -n "$role_arn" && "$role_arn" != "None" ]]; then
    IAM_ROLE_NAME="${role_arn##*/}"
    echo "  Found IAM role: $IAM_ROLE_NAME"
  else
    echo "  No IAM role found on Pod Identity association."
    IAM_ROLE_NAME=""
  fi
}

delete_service_account() {
  echo "==> Deleting ServiceAccount $SA_NAMESPACE/$SA_NAME..."
  kubectl delete sa "$SA_NAME" -n "$SA_NAMESPACE" --ignore-not-found=true
}

delete_pod_identity_association() {
  if [[ -z "${POD_IDENTITY_ASSOCIATION_ID:-}" ]]; then
    echo "==> No Pod Identity association to delete, skipping."
    return 0
  fi

  echo "==> Deleting Pod Identity association: $POD_IDENTITY_ASSOCIATION_ID..."
  aws eks delete-pod-identity-association \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --region "$EKS_REGION" \
    --association-id "$POD_IDENTITY_ASSOCIATION_ID"
  echo "  Pod Identity association deleted."
}

delete_iam_role() {
  if [[ -z "${IAM_ROLE_NAME:-}" ]]; then
    echo "==> No IAM role to delete, skipping."
    return 0
  fi

  echo "==> Deleting IAM Role: $IAM_ROLE_NAME..."

  if ! aws iam get-role --role-name "$IAM_ROLE_NAME" &>/dev/null; then
    echo "  IAM Role not found, skipping."
    return 0
  fi

  # Detach all managed policies from the role
  local policies
  policies="$(aws iam list-attached-role-policies --role-name "$IAM_ROLE_NAME" \
    --query 'AttachedPolicies[].PolicyArn' --output text)"
  for policy_arn in $policies; do
    echo "  Detaching policy: $policy_arn"
    aws iam detach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn "$policy_arn"
  done

  # Delete inline policies
  local inline
  inline="$(aws iam list-role-policies --role-name "$IAM_ROLE_NAME" \
    --query 'PolicyNames[]' --output text)"
  for policy_name in $inline; do
    echo "  Deleting inline policy: $policy_name"
    aws iam delete-role-policy --role-name "$IAM_ROLE_NAME" --policy-name "$policy_name"
  done

  # Delete instance profiles
  local profiles
  profiles="$(aws iam list-instance-profiles-for-role --role-name "$IAM_ROLE_NAME" \
    --query 'InstanceProfiles[].InstanceProfileName' --output text)"
  for profile in $profiles; do
    echo "  Removing role from instance profile: $profile"
    aws iam remove-role-from-instance-profile --role-name "$IAM_ROLE_NAME" \
      --instance-profile-name "$profile"
  done

  aws iam delete-role --role-name "$IAM_ROLE_NAME"
  echo "  IAM Role deleted."
}

delete_iam_policy() {
  echo "==> Deleting IAM Policy: $POLICY_ARN..."

  if ! aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "  IAM Policy not found, skipping."
    return 0
  fi

  # Detach from any remaining entities (belt-and-suspenders after role deletion)
  local roles
  roles="$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" \
    --query 'PolicyRoles[].RoleName' --output text)"
  for role in $roles; do
    echo "  Detaching from role: $role"
    aws iam detach-role-policy --role-name "$role" --policy-arn "$POLICY_ARN"
  done

  local users
  users="$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" \
    --query 'PolicyUsers[].UserName' --output text)"
  for user in $users; do
    echo "  Detaching from user: $user"
    aws iam detach-user-policy --user-name "$user" --policy-arn "$POLICY_ARN"
  done

  local groups
  groups="$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" \
    --query 'PolicyGroups[].GroupName' --output text)"
  for group in $groups; do
    echo "  Detaching from group: $group"
    aws iam detach-group-policy --group-name "$group" --policy-arn "$POLICY_ARN"
  done

  # Delete non-default policy versions
  local versions
  versions="$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
    --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)"
  for ver in $versions; do
    echo "  Deleting policy version: $ver"
    aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$ver"
  done

  aws iam delete-policy --policy-arn "$POLICY_ARN"
  echo "  IAM Policy deleted."
}

cfn_stack_exists() {
  local stack_name="${1:?stack_name is required}"
  aws cloudformation describe-stacks --stack-name "$stack_name" --region "$EKS_REGION" &>/dev/null
}

# Deletes a CloudFormation stack by name. Disables termination protection
# first if needed - eksctl enables it by default on stacks it creates, and
# delete-stack fails outright otherwise. Caller must have already confirmed
# the stack exists (via cfn_stack_exists).
delete_cfn_stack() {
  local stack_name="${1:?stack_name is required}"
  echo "==> Deleting CloudFormation stack: $stack_name..."

  local termination_protection
  termination_protection="$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$EKS_REGION" \
    --query 'Stacks[0].EnableTerminationProtection' --output text 2>/dev/null || true)"

  if [[ "$termination_protection" == "True" ]]; then
    echo "  Termination protection is enabled on this stack - disabling it first..."
    aws cloudformation update-termination-protection \
      --stack-name "$stack_name" \
      --region "$EKS_REGION" \
      --no-enable-termination-protection >/dev/null
  fi

  aws cloudformation delete-stack --stack-name "$stack_name" --region "$EKS_REGION"
  echo "  Waiting for stack deletion..."
  aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$EKS_REGION"
  echo "  Stack deleted."
}

# eksctl create iamserviceaccount / podidentityassociation each provision a
# CloudFormation stack to own the IAM role only when eksctl generated the role
# itself (no --role-arn/--attach-role-arn was passed). When that's the case,
# CloudFormation must be the one to delete the role - deleting it directly via
# the IAM API first (as this used to do) leaves the stack orphaned, unable to
# clean itself up. So: check for the stack first, and only fall back to a
# direct IAM role deletion when there isn't one (aws-cli-created roles).
# delete_auth_association
# Whatever created the ServiceAccount/IAM role pair (eksctl+CloudFormation,
# vs. this project's aws-cli install path) is the only thing that should ever
# delete it. Mutating a CloudFormation-owned role directly (attach/detach a
# policy, delete it, etc.) outside the stack diverges the stack's tracked
# state from live AWS state - CloudFormation doesn't re-derive what's
# actually attached, it trusts its own template, so a manual detour here is
# what caused the repeated eksctl "no tasks"/DELETE_FAILED/orphaned-role
# problems this project hit. So: if eksctl (via CloudFormation) created the
# binding, eksctl deletes it - full stop, no manual IAM API calls. Only when
# there's no CloudFormation stack at all (the aws-cli install path, which
# never involves eksctl) does this fall back to the raw IAM calls below.
delete_auth_association() {
  case "$AUTH_MODE" in
    irsa)
      local stack="eksctl-${EKS_CLUSTER_NAME}-addon-iamserviceaccount-${SA_NAMESPACE}-${SA_NAME}"
      if cfn_stack_exists "$stack"; then
        echo "==> ServiceAccount + IAM role are eksctl/CloudFormation-managed."
        echo "==> Deleting via 'eksctl delete iamserviceaccount' (owns the SA, role, and stack together)..."
        # No --approve: only valid alongside -f/--config-file (declarative
        # mode). In this imperative --name/--namespace form it applies
        # immediately and rejects --approve outright.
        if eksctl delete iamserviceaccount \
            --cluster="$EKS_CLUSTER_NAME" \
            --name="$SA_NAME" \
            --namespace="$SA_NAMESPACE" \
            --region="$EKS_REGION" \
            --wait; then
          echo "  Deleted via eksctl."
        else
          echo "  eksctl delete failed - falling back to direct CloudFormation stack deletion." >&2
          delete_service_account
          cfn_stack_exists "$stack" && delete_cfn_stack "$stack"
        fi
      else
        echo "==> No eksctl-managed CloudFormation stack found - this binding wasn't created by eksctl."
        extract_iam_role_from_sa
        delete_service_account
        delete_iam_role
      fi
      ;;
    pod-identity)
      # Pod Identity never annotates or otherwise owns the ServiceAccount
      # object (unlike IRSA), so this needs deleting regardless of path.
      delete_service_account

      local stack="eksctl-${EKS_CLUSTER_NAME}-podidentityrole-${SA_NAMESPACE}-${SA_NAME}"
      if cfn_stack_exists "$stack"; then
        echo "==> IAM role is eksctl/CloudFormation-managed."
        echo "==> Deleting via 'eksctl delete podidentityassociation' (owns the association and role/stack together)..."
        if eksctl delete podidentityassociation \
            --cluster="$EKS_CLUSTER_NAME" \
            --namespace="$SA_NAMESPACE" \
            --service-account-name="$SA_NAME" \
            --region="$EKS_REGION"; then
          echo "  Deleted via eksctl."
        else
          echo "  eksctl delete failed - falling back to direct CloudFormation stack deletion." >&2
          extract_iam_role_from_pod_identity
          delete_pod_identity_association
          cfn_stack_exists "$stack" && delete_cfn_stack "$stack"
        fi
      else
        echo "==> No eksctl-managed CloudFormation stack found - this binding wasn't created by eksctl."
        extract_iam_role_from_pod_identity
        delete_pod_identity_association
        delete_iam_role
      fi
      ;;
    *)
      echo "==> No IAM binding detected, skipping IAM role/association cleanup."
      ;;
  esac
}

main() {
  # deprovision_aws_load_balancers() deletes every load-balancer-provisioning
  # resource wholesale, polls detect_aws_load_balancers() until it reports
  # clean, and if the controller hasn't finished within the timeout, forces
  # finalizer removal as a last resort (force_clear_stuck_finalizers) and
  # re-checks. It only returns non-zero (with an itemized list already
  # printed) if the cluster is STILL not clean after all of that - at which
  # point continuing would be walking into a CRD-deletion or Helm-uninstall
  # hang, so abort instead.
  if ! deprovision_aws_load_balancers; then
    echo "❌ Aborting: cluster is not in a clean state for CRD/Helm teardown." >&2
    exit 1
  fi

  # By this point nothing that could block either step remains, so order
  # between them no longer matters for correctness - Helm then CRDs mirrors
  # how they were installed (CRDs, then Helm) run in reverse.
  uninstall_lbc_helm_chart
  uninstall_gateway_crds

  determine_auth_mode
  # delete_auth_association() prefers eksctl's own delete commands whenever
  # eksctl/CloudFormation created the binding - see its comment for why
  # manual IAM API calls against a CloudFormation-owned role are unsafe.
  delete_auth_association
  delete_iam_policy
  echo "Cleanup completed successfully!"
}

main
