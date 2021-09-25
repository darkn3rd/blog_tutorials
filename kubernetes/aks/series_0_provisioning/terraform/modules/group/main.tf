variable "name" {}
variable "location" {}
variable "create_group" { default = true }

locals {
  name     = var.create_group ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  location = var.create_group ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
}

resource "azurerm_resource_group" "rg" {
  count    = var.create_group ? 1 : 0
  name     = var.name
  location = var.location
}

# fetch resource if not creating the resource
data "azurerm_resource_group" "rg" {
  count = var.create_group ? 0 : 1
  name  = var.name
}

output "name" {
  value = local.name
}

output "location" {
  value = local.location
}
