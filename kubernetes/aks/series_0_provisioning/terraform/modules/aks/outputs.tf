output "name" {
  description = "The Kubernetes Managed Cluster name."
  value = azurerm_kubernetes_cluster.k8s.name
}

output "kubelet_identity" {
  description = "A kubelet_identity block"
  value       = azurerm_kubernetes_cluster.k8s.kubelet_identity
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.k8s.kube_config
}

output "kube_config_raw" {
  value       = azurerm_kubernetes_cluster.k8s.kube_config_raw
}
