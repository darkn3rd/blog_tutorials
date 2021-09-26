##########
# input variables
##########################

# azure dns
variable "dns_zone_group" {}
variable "dns_zone_location" {}
variable "create_dns_zone_group" { default = false }

variable "dns_prefix" {}
variable "create_dns_zone" { default = true }
variable "domain" {}
variable "subdomain_prefix" { default = "" }

# aks
variable "cluster_group" {}
variable "cluster_location" {}
variable "create_cluster_group" { default = false }
variable "cluster_name" {}

# managed identity role binding (kubelet id)
variable "enable_attach_dns" { default = false }

# kubernetes addons
variable "enable_external_dns" { default = true }
variable "enable_ingress_nginx" { default = false }
variable "enable_cert_manager" { default = false }
variable "acme_issuer_email" { default = "" } # required if cert_manager=true

##########
# data sources
##########################
data "azurerm_client_config" "current" {}

##########
# Azure Infrastructure
##########################
module "cluster_rg" {
  source       = "../modules/group"
  name         = var.cluster_group
  location     = var.cluster_location
  create_group = var.create_cluster_group
}

module "dns_zone_rg" {
  source       = "../modules/group"
  name         = var.dns_zone_group
  location     = var.dns_zone_location
  create_group = var.create_dns_zone_group
}

module "dns" {
  source              = "../modules/dns"
  resource_group_name = var.dns_zone_group
  domain              = var.domain
  subdomain_prefix    = var.subdomain_prefix
  create_dns_zone     = var.create_dns_zone
}

module "aks" {
  source              = "../modules/aks"
  resource_group_name = module.cluster_rg.name
  name                = var.cluster_name
  dns_prefix          = var.dns_prefix
}


##########
# Output variables
##########################
output "cluster_resource_group_location" {
  value = module.cluster_rg.location
}

output "cluster_resource_group_name" {
  value = module.cluster_rg.name
}

output "dns_zone_resource_group_name" {
  value = module.dns_zone_rg.name
}

output "dns_zone_resource_group_location" {
  value = module.dns_zone_rg.location
}

output "kubernetes_cluster_name" {
  value = module.aks.name
}

output "kubelet_identity_id" {
  value = module.aks.kubelet_identity[0].object_id
}

output "dns_zone_id" {
  value = module.dns.dns_zone_id
}

output "dns_zone_name" {
  value = module.dns.dns_zone_name
}
