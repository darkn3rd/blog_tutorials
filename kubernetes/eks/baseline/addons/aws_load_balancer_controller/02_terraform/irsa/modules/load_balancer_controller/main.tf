# Sets up the IRSA IAM role for the controller's service account
module "lbc_irsa" {
  source = "./lbc_irsa"

  eks_cluster_name = var.eks_cluster_name
  oidc_issuer_url  = var.oidc_issuer_url
}

# Installs the controller (service account, CRDs, Helm release), using the role from lbc_irsa
module "lbc_install" {
  source = "./lbc_install"

  eks_cluster_name             = var.eks_cluster_name
  eks_region                   = var.eks_region
  chart_version                = var.chart_version
  vpc_id                       = var.vpc_id
  role_arn                     = module.lbc_irsa.role_arn
  use_experimental_gateway_api = var.use_experimental_gateway_api
}
