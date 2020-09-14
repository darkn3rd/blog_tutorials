#####################################################################
## Variables - Required
#####################################################################
variable "storage_container_name" {}
variable "storage_account_name" {}
variable "resource_group_name" {}

#####################################################################
## Variables - Optional
#####################################################################
variable "resource_group_location" { default = "eastus" }
variable "environment" { default = "testing" }
variable "create_resource_group" { default = true }
variable "create_storage_account" { default = true }
