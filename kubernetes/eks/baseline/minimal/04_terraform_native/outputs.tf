output "eks_region" {
  value = var.eks_region
}

output "eks_cluster_name" {
  value = var.eks_cluster_name
}

output "vpc_id" {
  value = module.eks_network.vpc_id
}

output "cluster_summary" {
  value = module.eks_cluster.cluster_summary
}

output "network_summary" {
  value = module.eks_network.network_summary
}
