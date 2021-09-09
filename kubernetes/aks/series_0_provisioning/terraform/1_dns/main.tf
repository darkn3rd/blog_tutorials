# resource groups
variable "cluster_group" {}
variable "dns_zone_group" {}
variable "cluster_location" {}
variable "dns_zone_location" {}
variable "create_cluster_group" { default = false }
variable "create_dns_zone_group" { default = false }

# azure dns
variable "dns_prefix" {}
variable "cluster_name" {}

# aks
variable "create_dns_zone" { default = true }
variable "subdomain_prefix" { default = "" }
variable "domain" {}

# attach_dns - see warning
variable "enable_attach_dns" { default = false }

##########
# Azure Infrastructure
##########################
module "cluster_rg" {
  source       = "../modules/group"
  name         = var.cluster_name  # should be var.cluster_group
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
# attach_dns - this associates Azure DNS zone to the managed identity for the
#              VMSS of the default node  group.
#
# WARNING: Do NOT do this in produciton!
#          This allows ALL pods to access the Azure DNS Zone.  This is only used
#          for demonstration purposes for this tutorial.

# NOTE: See AAD Pod Identity to allow explicit pods to access the Azure DNS Zone
#       resource
##########################
resource "azurerm_role_assignment" "attach_dns" {
  count = var.enable_attach_dns ? 1 : 0

  scope                = module.dns.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = module.aks.kubelet_identity[0].object_id
}

##########
# Output variables
##########################
output "resource_group_name" {
  value = module.cluster_rg.name
}

output "resource_group_location" {
  value = module.cluster_rg.location
}

output "kubernetes_cluster_name" {
  value = module.aks.kubernetes_cluster_name
}
