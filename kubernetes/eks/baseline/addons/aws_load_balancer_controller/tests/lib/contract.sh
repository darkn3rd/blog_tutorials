#!/usr/bin/env bash
# lib/contract.sh — the 7 functions every phase script drives, dispatching
# per install_method so phases themselves never branch on it.
# Source this file; do not execute it directly.
#
# Requires: aws, kubectl, helm, jq, terraform (for install_method=terraform)
# Assumes: die() is defined by the sourcing script; EKS_CLUSTER_NAME,
#          EKS_REGION, AWS_PROFILE, KUBECONFIG are exported by the caller.

TESTS_DIR="${TESTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$TESTS_DIR/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$PROJECT_DIR/.." && pwd)}"

# shellcheck source=./yaml.sh
source "$TESTS_DIR/lib/yaml.sh"

DEMO_NAMESPACE_PREFIX="demo-"

# Dedups repeated terraform progress lines ("Still creating... [Ns elapsed]"
# heartbeats) so a slow apply/destroy doesn't spam the terminal, while any
# genuinely new/changed line always prints immediately; indents every line
# so it's visually clear it's raw terraform output, not this script's own.
# Used as a pipe stage (not exec >) - see call sites for why.
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
    printf '[%s]     | %s\n' "$(date -u +%H:%M:%S)" "$_line"
  done
}

# ── install_lbc ───────────────────────────────────────────────────────────

# install_lbc <install_method> <auth_mode>
install_lbc() {
  local install_method="${1:?install_method is required}"
  local auth_mode="${2:?auth_mode is required}"

  case "$install_method" in
    cli-eksctl) "$REPO_ROOT/install_aws_lbc.sh" eksctl "$auth_mode" ;;
    cli-aws) "$REPO_ROOT/install_aws_lbc.sh" aws-cli "$auth_mode" ;;
    terraform) install_lbc_terraform "$auth_mode" ;;
    python-direct-api) install_lbc_python_direct_api "$auth_mode" ;;
    python-exec-cli-eksctl) install_lbc_python_exec_cli eksctl "$auth_mode" ;;
    python-exec-cli-awscli) install_lbc_python_exec_cli aws-cli "$auth_mode" ;;
    *) die "Unknown install_method '$install_method'." ;;
  esac
}

# ensure_python_venv <dir>
# Creates .venv if missing, then installs requirements.txt every time -
# mirrors how install_lbc_terraform() calls `terraform init` every time
# (cheap no-op when nothing changed) rather than assuming a one-time manual
# setup step outside this framework. Re-running pip install on an
# already-satisfied venv is fast (pip skips anything already installed at
# the right version), so this stays cheap while also picking up a
# requirements.txt change (e.g. a newly added dependency) on an existing
# venv without the caller having to know to delete it first. Only needed
# for 03_python/direct_api (boto3/kubernetes/PyYAML) - 03_python/exec_cli
# has no pip dependencies at all (subprocess + stdlib only), so it just
# uses system python3 directly.
ensure_python_venv() {
  local dir="${1:?dir is required}"
  if [[ ! -x "$dir/.venv/bin/python" ]]; then
    echo "  Creating Python venv in $dir..."
    (cd "$dir" && python3 -m venv .venv && ./.venv/bin/pip install --quiet --upgrade pip)
  fi
  (cd "$dir" && ./.venv/bin/pip install --quiet -r requirements.txt)
}

install_lbc_python_direct_api() {
  local auth_mode="${1:?auth_mode is required}"
  local dir="$PROJECT_DIR/03_python/direct_api"
  ensure_python_venv "$dir"
  (cd "$dir" && ./.venv/bin/python install_aws_lbc.py "$auth_mode")
}

install_lbc_python_exec_cli() {
  local tool_mode="${1:?tool_mode is required}"
  local auth_mode="${2:?auth_mode is required}"
  local dir="$PROJECT_DIR/03_python/exec_cli"
  (cd "$dir" && python3 install_aws_lbc.py "$tool_mode" "$auth_mode")
}

# terraform_dir_for_auth_mode <auth_mode> -> stdout
terraform_dir_for_auth_mode() {
  local auth_mode="${1:?auth_mode is required}"
  case "$auth_mode" in
    irsa) echo "$PROJECT_DIR/irsa" ;;
    pod-identity) echo "$PROJECT_DIR/podid" ;;
    *) die "Unknown auth_mode '$auth_mode' for terraform install/uninstall." ;;
  esac
}

# verify_terraform_prereqs <auth_mode>
# Mirrors install_aws_lbc.sh's own verify_oidc_provider()/
# verify_pod_identity_addon() checks - the irsa/podid Terraform roots use
# data-source lookups for these, so terraform apply's failure mode for a
# missing prerequisite is an opaque provider error rather than a clear one.
verify_terraform_prereqs() {
  local auth_mode="${1:?auth_mode is required}"
  local account_id
  account_id="$(aws sts get-caller-identity --query Account --output text)"

  if [[ "$auth_mode" == "irsa" ]]; then
    local oidc_url oidc_provider
    oidc_url="$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" \
      --query "cluster.identity.oidc.issuer" --output text)"
    oidc_provider="${oidc_url#https://}"
    aws iam get-open-id-connect-provider \
      --open-id-connect-provider-arn "arn:aws:iam::${account_id}:oidc-provider/${oidc_provider}" \
      >/dev/null 2>&1 \
      || die "No IAM OIDC provider associated with cluster '$EKS_CLUSTER_NAME'. Run: eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --region $EKS_REGION --approve"
  else
    aws eks describe-addon --cluster-name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" \
      --addon-name eks-pod-identity-agent >/dev/null 2>&1 \
      || die "eks-pod-identity-agent addon not installed on cluster '$EKS_CLUSTER_NAME'. Run: aws eks create-addon --cluster-name $EKS_CLUSTER_NAME --addon-name eks-pod-identity-agent --region $EKS_REGION"
  fi
}

# tfvars_file_for_case -> stdout
# Deterministic per CASE_NAME (not a datestamp) - install and uninstall each
# compute this independently and need to agree on the same filename without
# passing state between them. Named test_<case>.tfvars, same reasoning as
# phases/00_provision_cluster.sh: irsa/ and podid/ each already have their
# own terraform.tfvars for manual/non-test use (eks_cluster_name =
# "modcluster"), so writing to that path directly would clobber it.
tfvars_file_for_case() {
  : "${CASE_NAME:?CASE_NAME is required}"
  echo "test_${CASE_NAME}.tfvars"
}

install_lbc_terraform() {
  local auth_mode="${1:?auth_mode is required}"
  local tf_dir tfvars_file
  tf_dir="$(terraform_dir_for_auth_mode "$auth_mode")"
  tfvars_file="$(tfvars_file_for_case)"

  : "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
  verify_terraform_prereqs "$auth_mode"
  local eks_version eks_region
  eks_version="$(matrix_cluster_field eks_version)"
  eks_region="${EKS_REGION:-$(matrix_cluster_field eks_region)}"

  cat > "$tf_dir/$tfvars_file" <<EOF
eks_cluster_name = "${EKS_CLUSTER_NAME}"
eks_region        = "${eks_region}"
eks_version       = "${eks_version}"
EOF

  # Scoped to just this command's output (not `exec >` at file scope) -
  # contract.sh is sourced into many different scripts, and a global exec
  # redirect here would silently change stdout for the rest of whatever
  # script called this function. Piping through `while` makes $? reflect the
  # while loop, not terraform, regardless of the caller's pipefail setting -
  # PIPESTATUS[0] is captured and returned explicitly so a failed apply
  # still fails this function.
  (cd "$tf_dir" && terraform init -input=false -no-color && terraform apply -var-file="$tfvars_file" -auto-approve -no-color) \
    2>&1 | _tool_output_filter
  return "${PIPESTATUS[0]}"
}

# ── uninstall_lbc ─────────────────────────────────────────────────────────

# uninstall_lbc <install_method> <auth_mode>
# NEVER run uninstall_aws_lbc.sh against a terraform-installed case: it owns
# these resources via Terraform state, not CloudFormation. Mixing the two
# reintroduces the exact ownership-drift bug class this project already hit
# once with CloudFormation - only through Terraform state instead.
uninstall_lbc() {
  local install_method="${1:?install_method is required}"
  local auth_mode="${2:?auth_mode is required}"

  case "$install_method" in
    cli-eksctl|cli-aws) "$REPO_ROOT/uninstall_aws_lbc.sh" ;;
    terraform) uninstall_lbc_terraform "$auth_mode" ;;
    python-direct-api) uninstall_lbc_python_direct_api ;;
    python-exec-cli-eksctl|python-exec-cli-awscli) uninstall_lbc_python_exec_cli ;;
    *) die "Unknown install_method '$install_method'." ;;
  esac
}

# uninstall_aws_lbc.py self-detects auth mode (and, for exec_cli, whether
# eksctl/CloudFormation owns the binding) the same way the bash version
# does, so both exec-cli tool variants share one uninstall function - there
# is no tool_mode to pass at uninstall time.
uninstall_lbc_python_direct_api() {
  local dir="$PROJECT_DIR/03_python/direct_api"
  ensure_python_venv "$dir"
  (cd "$dir" && ./.venv/bin/python uninstall_aws_lbc.py)
}

uninstall_lbc_python_exec_cli() {
  local dir="$PROJECT_DIR/03_python/exec_cli"
  (cd "$dir" && python3 uninstall_aws_lbc.py)
}

uninstall_lbc_terraform() {
  local auth_mode="${1:?auth_mode is required}"
  local tf_dir tfvars_file
  tf_dir="$(terraform_dir_for_auth_mode "$auth_mode")"
  tfvars_file="$(tfvars_file_for_case)"
  [[ -f "$tf_dir/$tfvars_file" ]] \
    || die "No $tfvars_file in $tf_dir - was install_lbc ever run for this case?"
  # See install_lbc_terraform()'s comment on why this is a scoped pipe (not
  # exec >) and why PIPESTATUS[0] is captured explicitly - doubly so here,
  # since the rm afterward would otherwise mask a failed destroy entirely.
  (cd "$tf_dir" && terraform destroy -var-file="$tfvars_file" -auto-approve -no-color) \
    2>&1 | _tool_output_filter
  local rc="${PIPESTATUS[0]}"
  rm -f "$tf_dir/$tfvars_file"
  return "$rc"
}

# ── validate_lbc ──────────────────────────────────────────────────────────

# validate_lbc
# Install-method-agnostic: all three validate_*.sh scripts discover the
# role/policy from the live ServiceAccount rather than needing to be told
# how LBC was installed.
validate_lbc() {
  : "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
  : "${EKS_REGION:?EKS_REGION is required}"
  local scripts_dir="$PROJECT_DIR/01_cli/scripts"
  local rc=0

  "$scripts_dir/validate_crds.sh" || rc=1
  "$scripts_dir/validate_iam_policy.sh" -c "$EKS_CLUSTER_NAME" -r "$EKS_REGION" || rc=1
  "$scripts_dir/validate_auth.sh" -c "$EKS_CLUSTER_NAME" -r "$EKS_REGION" || rc=1

  return $rc
}

# ── demos ─────────────────────────────────────────────────────────────────
# Always demos/cli, regardless of install_method - demos/tf exists as a
# Terraform-based alternative but isn't used here for simplicity/speed.

deploy_demos() {
  "$PROJECT_DIR/demos/cli/deploy_demos.sh"
}

cleanup_demos() {
  "$PROJECT_DIR/demos/cli/clean_demos.sh"
}

validate_demos() {
  "$PROJECT_DIR/demos/test_demos.sh"
}

# ── verify_clean ──────────────────────────────────────────────────────────
# Independent of uninstall_aws_lbc.sh's internal detect_aws_load_balancers()
# by design - this is the test framework's own oracle, not a trust of the
# thing under test. Checks are wholesale/name-agnostic wherever the
# resource's name is user-choosable (namespaces, Gateway API objects), and
# convention-based only where the name is one this project's own tooling
# fixes deterministically (the IAM policy name, the two known IAM role/CFN
# stack naming conventions).

# _list_all_of_kind <kind> -> stdout, "namespace/name" or "name" per line
_list_all_of_kind() {
  local kind="${1:?kind is required}"
  kubectl get "$kind" --all-namespaces -o json 2>/dev/null \
    | jq -r '.items[]? | if .metadata.namespace then "\(.metadata.namespace)/\(.metadata.name)" else .metadata.name end'
}

# _find_alb_ingresses -> stdout, one "namespace/name" per line
# Mirrors uninstall_aws_lbc.sh's find_alb_ingresses() exactly, including its
# fix for the deprecated kubernetes.io/ingress.class annotation: matching
# only via a registered IngressClass object's controller misses every
# annotation-only ALB Ingress when no IngressClass object exists at all (a
# real, observed case) - "alb" is safe to match directly for that one
# annotation since it's AWS LBC's own fixed literal value, not a
# user-arbitrary name.
_find_alb_ingresses() {
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

# _find_aws_lb_services -> stdout, one "namespace/name" per line
# Mirrors uninstall_aws_lbc.sh's find_aws_lb_services() - matched by the
# fixed annotation values / loadBalancerClass prefix AWS LBC itself
# recognizes, not by a user-renameable class name.
_find_aws_lb_services() {
  kubectl get svc --all-namespaces -o json 2>/dev/null | jq -r '
    .items[] |
    select(
      .spec.type == "LoadBalancer" and (
        (.metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-type"] as $t | $t == "nlb" or $t == "external" or $t == "nlb-ip") or
        ((.spec.loadBalancerClass // "") | startswith("service.k8s.aws/"))
      )
    ) | "\(.metadata.namespace)/\(.metadata.name)"'
}

# verify_clean <install_method> [--skip-namespaces]
# Prints an itemized list of anything still present to stderr and returns 1
# if the cluster/account is not fully clean. Silent and returns 0 if clean.
# --skip-namespaces: demo namespace teardown is cleanup_demos()'s job (phase
# 07), not uninstall_lbc()'s (phase 08) - a caller checking LBC-only
# state before phase 07 has run (e.g. suites/negative_finalizer_lock.sh,
# which calls uninstall_lbc directly at phase 06) needs to skip the
# namespace check or every such call would report a false failure.
verify_clean() {
  local install_method="${1:?install_method is required}"
  local skip_namespaces="false"
  [[ "${2:-}" == "--skip-namespaces" ]] && skip_namespaces="true"
  local -a remaining=()

  # Demo namespaces - convention: every demo (canonical or negative-suite
  # generated) is namespaced "demo-*". See suites/negative_extra_lbs.sh.
  if [[ "$skip_namespaces" == "false" ]]; then
    local ns
    while IFS= read -r ns; do
      [[ -n "$ns" ]] && remaining+=("Namespace: $ns")
    done < <(kubectl get namespace -o json 2>/dev/null \
      | jq -r --arg prefix "$DEMO_NAMESPACE_PREFIX" '.items[] | select(.metadata.name | startswith($prefix)) | .metadata.name')
  fi

  # ALB Ingresses / NLB-or-ALB Services - previously missing entirely from
  # this function, relying only on the (skippable) namespace check above to
  # catch a stuck one indirectly. Direct checks now, matching
  # uninstall_aws_lbc.sh's detect_aws_load_balancers() exactly.
  local entry
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && remaining+=("Ingress: $entry")
  done < <(_find_alb_ingresses)
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && remaining+=("Service: $entry")
  done < <(_find_aws_lb_services)

  # Gateway API objects - wholesale, any kind, any name/class.
  if kubectl api-resources --api-group=gateway.networking.k8s.io &>/dev/null 2>&1; then
    local kind entry
    for kind in gateway httproute grpcroute tcproute tlsroute udproute referencegrant gatewayclass; do
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && remaining+=("$kind: $entry")
      done < <(_list_all_of_kind "$kind")
    done
  fi
  local kind
  for kind in loadbalancerconfiguration targetgroupconfiguration listenerruleconfiguration; do
    if kubectl api-resources --api-group=gateway.k8s.aws 2>/dev/null | grep -qi "^${kind}"; then
      local entry
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && remaining+=("$kind: $entry")
      done < <(_list_all_of_kind "$kind")
    fi
  done

  # TargetGroupBinding/IngressClassParams/ALBTargetControlConfig
  # (elbv2.k8s.aws) - the controller's own core CRDs, bundled directly in
  # the Helm chart rather than fetched separately like the Gateway API ones.
  # TargetGroupBinding in particular is created for EVERY Service/Ingress/
  # Gateway the controller provisions a load balancer for, and blocks its
  # namespace's deletion the same way a stuck Gateway does - missed here
  # (and in uninstall_aws_lbc.sh, now fixed there) until a namespace got
  # stuck deleting with a live TargetGroupBinding and no controller left to
  # clear its finalizer.
  for kind in targetgroupbinding ingressclassparams albtargetcontrolconfigs; do
    if kubectl api-resources --api-group=elbv2.k8s.aws 2>/dev/null | grep -qi "^${kind}"; then
      local entry
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && remaining+=("$kind: $entry")
      done < <(_list_all_of_kind "$kind")
    fi
  done

  # GlobalAccelerator (aga.k8s.aws) - a separate API group, same bundled-in-
  # the-Helm-chart reasoning as the elbv2.k8s.aws ones above. Found by going
  # to the actual upstream CRD bundle instead of continuing to hand-maintain
  # a name list - do that again before trusting this list is exhaustive.
  if kubectl api-resources --api-group=aga.k8s.aws 2>/dev/null | grep -qi "^globalaccelerator"; then
    local entry
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && remaining+=("globalaccelerator: $entry")
    done < <(_list_all_of_kind globalaccelerator)
  fi

  # Gateway API + elbv2.k8s.aws + aga.k8s.aws CRDs themselves should be gone
  # too - a truly clean uninstall removes them, not just the instances.
  local crd
  while IFS= read -r crd; do
    [[ -n "$crd" ]] && remaining+=("CRD: $crd")
  done < <(kubectl get crd -o name 2>/dev/null | grep -E "gateway\.k8s\.aws|gateway\.networking\.k8s\.io|elbv2\.k8s\.aws|aga\.k8s\.aws" || true)

  # Helm release / controller pods / ServiceAccount.
  if helm status aws-load-balancer-controller --namespace kube-system &>/dev/null; then
    remaining+=("Helm release: aws-load-balancer-controller")
  fi
  if kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o name 2>/dev/null | grep -q .; then
    remaining+=("Pods: aws-load-balancer-controller in kube-system")
  fi
  if kubectl get sa aws-load-balancer-controller -n kube-system &>/dev/null; then
    remaining+=("ServiceAccount: kube-system/aws-load-balancer-controller")
  fi

  # AWS load balancers/target groups tagged as owned by this cluster.
  local lb_arns
  lb_arns="$(aws elbv2 describe-load-balancers --region "$EKS_REGION" \
    --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null || true)"
  local arn
  for arn in $lb_arns; do
    local owned
    owned="$(aws elbv2 describe-tags --region "$EKS_REGION" --resource-arns "$arn" \
      --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster' && Value=='${EKS_CLUSTER_NAME}'] | length(@)" \
      --output text 2>/dev/null || echo 0)"
    [[ "$owned" != "0" ]] && remaining+=("AWS LoadBalancer: $arn")
  done

  # IAM policy - fixed name for cli-*/terraform; cluster-scoped for every
  # python-* install method regardless of tool_mode (see
  # 03_python/*/lib/naming.py - direct_api and both exec_cli tool paths all
  # compute the same scoped name from EKS_CLUSTER_NAME). This bash replica
  # doesn't implement naming.py's long-cluster-name truncation+hash
  # fallback, so it only matches correctly for cluster names short enough
  # to never trigger that path - true for every name this framework
  # generates, but worth re-checking if that naming scheme changes.
  local policy_name="AWSLoadBalancerControllerIAMPolicy"
  case "$install_method" in
    python-*) policy_name="AWSLoadBalancerControllerIAMPolicy-${EKS_CLUSTER_NAME}" ;;
  esac
  if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}:policy/${policy_name}" &>/dev/null; then
    remaining+=("IAM Policy: ${policy_name}")
  fi

  # IAM role / CloudFormation stack, or Terraform-managed role - naming
  # convention is fixed per install_method (not user-choosable), so this is
  # a legitimate deterministic check, unlike the Gateway API instance scan
  # above.
  case "$install_method" in
    cli-eksctl|cli-aws|python-exec-cli-eksctl)
      # eksctl's own CFN stack naming is invocation-agnostic - the same
      # stack names apply whether eksctl was invoked directly (cli-eksctl)
      # or via 03_python/exec_cli's subprocess wrapper.
      local stack
      for stack in \
        "eksctl-${EKS_CLUSTER_NAME}-addon-iamserviceaccount-kube-system-aws-load-balancer-controller" \
        "eksctl-${EKS_CLUSTER_NAME}-podidentityrole-kube-system-aws-load-balancer-controller"; do
        if aws cloudformation describe-stacks --stack-name "$stack" --region "$EKS_REGION" &>/dev/null; then
          remaining+=("CloudFormation stack: $stack")
        fi
      done
      ;;
    terraform)
      if aws iam get-role --role-name "${EKS_CLUSTER_NAME}-aws-load-balancer-controller" &>/dev/null; then
        remaining+=("IAM Role: ${EKS_CLUSTER_NAME}-aws-load-balancer-controller")
      fi
      ;;
    python-direct-api|python-exec-cli-awscli)
      # Cluster-scoped role name (see 03_python/*/lib/naming.py) - only
      # created via direct IAM API calls, not eksctl/CloudFormation, on
      # these two paths.
      if aws iam get-role --role-name "AmazonEKSLoadBalancerControllerRole-${EKS_CLUSTER_NAME}" &>/dev/null; then
        remaining+=("IAM Role: AmazonEKSLoadBalancerControllerRole-${EKS_CLUSTER_NAME}")
      fi
      ;;
  esac

  if [[ ${#remaining[@]} -gt 0 ]]; then
    echo "❌ ${#remaining[@]} resource(s) remain - not clean:" >&2
    printf '     %s\n' "${remaining[@]}" >&2
    return 1
  fi

  return 0
}
