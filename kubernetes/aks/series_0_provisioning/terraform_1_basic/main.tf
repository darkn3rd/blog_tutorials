variable "resource_group_name" {}
variable "location" {}
variable "dns_prefix" {}
variable "cluster_name" {}

module "rg" {
  source   = "./modules/group"
  name     = var.resource_group_name
  location = var.location
}

module "aks" {
  source              = "./modules/aks"
  name                = var.cluster_name
  dns_prefix          = var.dns_prefix
  resource_group_name = var.resource_group_name

}

output "resource_group_name" {
  value = module.aks.resource_group_name
}

output "kubernetes_cluster_name" {
  value = module.aks.kubernetes_cluster_name
}
