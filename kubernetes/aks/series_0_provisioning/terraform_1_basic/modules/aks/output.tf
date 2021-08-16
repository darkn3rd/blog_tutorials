output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.k8s.name
}

output "resource_group_name" {
  value = data.azurerm_resource_group.rg.name
}
