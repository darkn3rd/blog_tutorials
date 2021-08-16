variable "name" {}
variable "location" {}

resource "azurerm_resource_group" "rg" {
  name     = var.name
  location = var.location
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
