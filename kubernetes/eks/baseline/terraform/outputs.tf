output "eks_region" {
  value = var.eks_region
}

output "eks_cluster_name" {
  value = var.eks_cluster_name
}

output "vpc_id" {
  value = module.eks_network.vpc_id
}