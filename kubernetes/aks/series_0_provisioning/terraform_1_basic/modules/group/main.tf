variable "name" {}
variable "location" {}
variable "create_group" { default = true }

resource "azurerm_resource_group" "rg" {
  count    = var.create_group ? 0 : 1
  name     = var.name
  location = var.location
}

output "resource_group_name" {
  value = azurerm_resource_group.rg[0].name
}
