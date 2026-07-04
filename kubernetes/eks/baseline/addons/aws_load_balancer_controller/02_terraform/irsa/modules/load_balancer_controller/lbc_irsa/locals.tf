locals {
  # stripped OIDC issuer, used for IAM condition variables
  oidc_provider_path = replace(var.oidc_issuer_url, "https://", "")
}
