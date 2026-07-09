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

# ── install_lbc ───────────────────────────────────────────────────────────

# install_lbc <install_method> <auth_mode>
install_lbc() {
  local install_method="${1:?install_method is required}"
  local auth_mode="${2:?auth_mode is required}"

  case "$install_method" in
    cli-eksctl) "$REPO_ROOT/install_aws_lbc.sh" eksctl "$auth_mode" ;;
    cli-aws) "$REPO_ROOT/install_aws_lbc.sh" aws-cli "$auth_mode" ;;
    terraform) install_lbc_terraform "$auth_mode" ;;
    *) die "Unknown install_method '$install_method'." ;;
  esac
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

  (cd "$tf_dir" && terraform init -input=false && terraform apply -var-file="$tfvars_file" -auto-approve)
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
    *) die "Unknown install_method '$install_method'." ;;
  esac
}

uninstall_lbc_terraform() {
  local auth_mode="${1:?auth_mode is required}"
  local tf_dir tfvars_file
  tf_dir="$(terraform_dir_for_auth_mode "$auth_mode")"
  tfvars_file="$(tfvars_file_for_case)"
  [[ -f "$tf_dir/$tfvars_file" ]] \
    || die "No $tfvars_file in $tf_dir - was install_lbc ever run for this case?"
  (cd "$tf_dir" && terraform destroy -var-file="$tfvars_file" -auto-approve)
  rm -f "$tf_dir/$tfvars_file"
}

# ── validate_lbc ──────────────────────────────────────────────────────────

# validate_lbc
# Install-method-agnostic: all three validate_*.sh scripts discover the
# role/policy from the live ServiceAccount rather than needing to be told
# how LBC was installed.
validate_lbc() {
  : "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
  : "${EKS_REGION:?EKS_REGION is required}"
  local scripts_dir="$PROJECT_DIR/scripts"
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
  "$PROJECT_DIR/demos/cli/create_demos.sh"
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

# verify_clean <install_method>
# Prints an itemized list of anything still present to stderr and returns 1
# if the cluster/account is not fully clean. Silent and returns 0 if clean.
verify_clean() {
  local install_method="${1:?install_method is required}"
  local -a remaining=()

  # Demo namespaces - convention: every demo (canonical or negative-suite
  # generated) is namespaced "demo-*". See suites/negative_extra_lbs.sh.
  local ns
  while IFS= read -r ns; do
    [[ -n "$ns" ]] && remaining+=("Namespace: $ns")
  done < <(kubectl get namespace -o json 2>/dev/null \
    | jq -r --arg prefix "$DEMO_NAMESPACE_PREFIX" '.items[] | select(.metadata.name | startswith($prefix)) | .metadata.name')

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

  # Gateway API CRDs themselves should be gone too - a truly clean uninstall
  # removes them, not just the instances.
  local crd
  while IFS= read -r crd; do
    [[ -n "$crd" ]] && remaining+=("CRD: $crd")
  done < <(kubectl get crd -o name 2>/dev/null | grep -E "gateway\.k8s\.aws|gateway\.networking\.k8s\.io" || true)

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

  # IAM policy - same fixed name regardless of install_method.
  if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}:policy/AWSLoadBalancerControllerIAMPolicy" &>/dev/null; then
    remaining+=("IAM Policy: AWSLoadBalancerControllerIAMPolicy")
  fi

  # IAM role / CloudFormation stack, or Terraform-managed role - naming
  # convention is fixed per install_method (not user-choosable), so this is
  # a legitimate deterministic check, unlike the Gateway API instance scan
  # above.
  case "$install_method" in
    cli-eksctl|cli-aws)
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
  esac

  if [[ ${#remaining[@]} -gt 0 ]]; then
    echo "❌ ${#remaining[@]} resource(s) remain - not clean:" >&2
    printf '     %s\n' "${remaining[@]}" >&2
    return 1
  fi

  return 0
}
