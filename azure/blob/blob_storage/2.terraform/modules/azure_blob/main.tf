#####################################################################
## Data Sources
#####################################################################
data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "signed_in_user" {}

## Reference existing Storage Account if one is not creatd
data "azurerm_storage_account" "default" {
  count               = var.create_storage_account ? 0 : 1
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

## Reference Resource Group if not createdW
data "azurerm_resource_group" "default" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

#####################################################################
## Resources
#####################################################################

## Condtionally Create Resource Group
resource "azurerm_resource_group" "default" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.resource_group_location == "" ? "West US 2" : var.resource_group_location

  tags = {
    environment = var.environment
  }
}

## Create Storage Account + Grant Access to Storage Account + Container
resource "azurerm_storage_account" "default" {
  count                    = var.create_storage_account ? 1 : 0
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = local.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  tags = {
    environment = var.environment
  }
}

resource "azurerm_role_assignment" "default" {
  count                = var.create_storage_account ? 1 : 0
  scope                = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.signed_in_user.object_id
  depends_on           = [azurerm_storage_account.default]
}

resource "azurerm_storage_container" "default" {
  count                 = var.create_storage_account ? 1 : 0
  name                  = var.storage_container_name
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
  depends_on            = [azurerm_role_assignment.default]
}

## Create Container in existing Storage Account
##  Assume Access Is Already Granted
resource "azurerm_storage_container" "existing_storage_account" {
  count                 = var.create_storage_account ? 0 : 1
  name                  = var.storage_container_name
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}
