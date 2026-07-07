# Sets up IAM auth for the controller's service account (IRSA or Pod
# Identity, per auth_mode)
module "lbc_auth" {
  source = "../lbc_auth"

  auth_mode        = var.auth_mode
  eks_cluster_name = var.eks_cluster_name
  oidc_issuer_url  = var.oidc_issuer_url
  role_name        = var.role_name
  policy_name      = var.policy_name
}

# Prepares the cluster for the controller (service account, Gateway API
# CRDs). role_arn is only passed for IRSA -- Pod Identity's association
# (created inside lbc_auth) handles the IAM binding out-of-band instead of
# via a ServiceAccount annotation.
module "lbc_prep" {
  source = "../lbc_prep"

  role_arn = var.auth_mode == "irsa" ? module.lbc_auth.role_arn : null
}
