module "load_balancer_controller" {
  source = "./modules/load_balancer_controller"

  eks_cluster_name = var.eks_cluster_name
  eks_region       = var.eks_region
  chart_version    = var.chart_version
  vpc_id           = local.vpc_id
  oidc_issuer_url  = local.oidc_issuer_url
}
