variable "resource_group_name" {}
variable "location" {}
variable "dns_prefix" {}
variable "cluster_name" {}
variable "create_group" { default = false }

module "rg" {
  source       = "../modules/group"
  name         = var.resource_group_name
  location     = var.location
  create_group = var.create_group
}

module "aks" {
  source              = "../modules/aks"
  name                = var.cluster_name
  dns_prefix          = var.dns_prefix
  resource_group_name = var.resource_group_name
}

output "resource_group_name" {
  value = module.rg.name
}

output "resource_group_location" {
  value = module.rg.location
}

output "kubernetes_cluster_name" {
  value = module.aks.name
}

output "kubernetes_config" {
  value = module.aks.kube_config_raw
  sensitive = true
}
