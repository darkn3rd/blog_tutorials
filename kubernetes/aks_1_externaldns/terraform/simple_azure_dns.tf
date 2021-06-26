### Input Variables
variable "resource_group_name" {}
variable "domain_name" {}

### Azure DNS Zone Reource
resource "azurerm_dns_zone" "default" {
  name                = var.domain_name
  resource_group_name = var.resource_group_name
}

### Provider Requirements
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}
