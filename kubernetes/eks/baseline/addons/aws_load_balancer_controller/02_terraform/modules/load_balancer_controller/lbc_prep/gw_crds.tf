# Gateway API ships two mutually exclusive CRD channels; only one may be installed at a time.
# https://gateway-api.sigs.k8s.io/concepts/versioning/#release-channels
data "http" "stnd_gateway_api_crds" {
  count = var.use_experimental_gateway_api ? 0 : 1
  url   = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml"
}

data "http" "expr_gateway_api_crds" {
  count = var.use_experimental_gateway_api ? 1 : 0
  url   = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml"
}

# Safely parses and splits the multi-document YAML natively
data "kubectl_file_documents" "stnd_gateway_api_docs" {
  count   = var.use_experimental_gateway_api ? 0 : 1
  content = data.http.stnd_gateway_api_crds[0].response_body
}

data "kubectl_file_documents" "expr_gateway_api_docs" {
  count   = var.use_experimental_gateway_api ? 1 : 0
  content = data.http.expr_gateway_api_crds[0].response_body
}

locals {
  gateway_api_manifests = var.use_experimental_gateway_api ? data.kubectl_file_documents.expr_gateway_api_docs[0].manifests : data.kubectl_file_documents.stnd_gateway_api_docs[0].manifests
}

# Core Gateway API Manifests (whichever channel is selected)
resource "kubectl_manifest" "gateway_api" {
  for_each  = local.gateway_api_manifests
  yaml_body = each.value

  server_side_apply = true
}

# Fetch the AWS Load Balancer Controller Specific Gateway CRDs from GitHub - always installed
data "http" "aws_lbc_gateway_crds" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml"
}

# Parse and splits the AWS multi-document YAML natively
data "kubectl_file_documents" "aws_lbc_gateway_docs" {
  content = data.http.aws_lbc_gateway_crds.response_body
}

# AWS LBC Specific Manifests
resource "kubectl_manifest" "aws_lbc_gateway" {
  for_each  = data.kubectl_file_documents.aws_lbc_gateway_docs.manifests
  yaml_body = each.value

  server_side_apply = true
}

# The controller's own core CRDs (elbv2.k8s.aws: TargetGroupBinding,
# IngressClassParams, ALBTargetControlConfig; aga.k8s.aws: GlobalAccelerator)
# are bundled directly in the Helm chart's crds/ directory and auto-install
# on `helm install` - but Helm deliberately never deletes CRDs it installed
# on `helm uninstall`, and nothing else in this module tracked them, so
# `terraform destroy` was leaking all four every time. Applying them here
# (same pattern as the Gateway CRDs above) gives Terraform state ownership
# so destroy actually removes them; Helm's own bundled install sees them
# already present and no-ops.
data "http" "aws_lbc_core_crds" {
  url = "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml"
}

data "kubectl_file_documents" "aws_lbc_core_docs" {
  content = data.http.aws_lbc_core_crds.response_body
}

resource "kubectl_manifest" "aws_lbc_core" {
  for_each  = data.kubectl_file_documents.aws_lbc_core_docs.manifests
  yaml_body = each.value

  server_side_apply = true
}
