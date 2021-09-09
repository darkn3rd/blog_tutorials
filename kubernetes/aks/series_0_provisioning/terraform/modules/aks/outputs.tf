output "kubernetes_cluster_name" {
  description = "The Kubernetes Managed Cluster name."
  value = azurerm_kubernetes_cluster.k8s.name
}

output "resource_group_name" {
  value = data.azurerm_resource_group.rg.name
}

output "kubelet_identity" {
  description = "A kubelet_identity block"
  value       = azurerm_kubernetes_cluster.k8s.kubelet_identity
}
