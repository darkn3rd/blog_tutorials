module "eks_network" {
  source = "../shared_lib/terraform/modules/eks_network"

  eks_cluster_name = var.eks_cluster_name
  eks_region       = var.eks_region
}

module "eks_clusterconfig" {
  source = "../shared_lib/terraform/modules/eks_clusterconfig"

  eks_cluster_name = var.eks_cluster_name
  eks_region       = var.eks_region
  eks_version      = var.eks_version

  vpc_id             = module.eks_network.vpc_id
  public_subnet_ids  = module.eks_network.public_subnet_ids
  private_subnet_ids = module.eks_network.private_subnet_ids
}
