#####################################################################
## Locals
#####################################################################
locals {
  resource_group_location = var.create_resource_group ? azurerm_resource_group.default[0].location : data.azurerm_resource_group.default[0].location
  account_name            = var.create_storage_account ? "${join("", azurerm_storage_account.default.*.name)}" : "${join("", data.azurerm_storage_account.default.*.name)}"
  account_key             = var.create_storage_account ? "${join("", azurerm_storage_account.default.*.primary_access_key)}" : "${join("", data.azurerm_storage_account.default.*.primary_access_key)}"
  resource_name           = var.create_resource_group ? "${join("", azurerm_resource_group.default.*.name)}" : "${join("", data.azurerm_resource_group.default.*.name)}"
}
