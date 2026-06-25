data "http" "stnd_gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml"
}

# Fetch the Gateway API Experimental CRDs from GitHub
data "http" "expr_gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/experimental-install.yaml"
}

# Safely parses and splits the multi-document YAML natively
data "kubectl_file_documents" "stnd_gateway_api_docs" {
  content = data.http.stnd_gateway_api_crds.response_body
}

data "kubectl_file_documents" "expr_gateway_api_docs" {
  content = data.http.expr_gateway_api_crds.response_body
}

# 2. Fetch the AWS Load Balancer Controller Specific CRDs from GitHub
data "http" "aws_lbc_gateway_crds" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml"
}

# Parse and splits the AWS multi-document YAML natively
data "kubectl_file_documents" "aws_lbc_gateway_docs" {
  content = data.http.aws_lbc_gateway_crds.response_body
}

# Core Gateway API Manifests
resource "kubectl_manifest" "stnd_gateway_api" {
  # Natively loops through the safely extracted map of documents
  for_each  = data.kubectl_file_documents.stnd_gateway_api_docs.manifests
  yaml_body = each.value

  server_side_apply = true
}

resource "kubectl_manifest" "expr_gateway_api" {
  # Natively loops through the safely extracted map of documents
  for_each  = data.kubectl_file_documents.expr_gateway_api_docs.manifests
  yaml_body = each.value

  server_side_apply = true
}

# AWS LBC Specific Manifests
resource "kubectl_manifest" "aws_lbc_gateway" {
  for_each  = data.kubectl_file_documents.aws_lbc_gateway_docs.manifests
  yaml_body = each.value

  server_side_apply = true
}
