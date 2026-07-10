# Sets up IAM auth (IRSA) and prepares the cluster (service account, Gateway
# API CRDs) for the controller. Grouped into one module so both can be
# applied together with `terraform apply -target="module.lbc_setup"` ahead
# of the Helm install.
module "lbc_setup" {
  source = "../modules/load_balancer_controller/lbc_setup"

  auth_mode        = "irsa"
  eks_cluster_name = var.eks_cluster_name
  oidc_issuer_url  = local.oidc_issuer_url
  role_name        = var.role_name
  policy_name      = var.policy_name
}

# Installs the controller via Helm, using the service account from lbc_setup
module "lbc_install" {
  source = "../modules/load_balancer_controller/lbc_install"

  eks_cluster_name = var.eks_cluster_name
  eks_region       = var.eks_region
  chart_version    = var.chart_version
  vpc_id           = local.vpc_id
  sa_name          = module.lbc_setup.sa_name

  # Ensure the service account annotation and CRDs exist before Helm tries to initialize the pods
  depends_on = [module.lbc_setup]
}
