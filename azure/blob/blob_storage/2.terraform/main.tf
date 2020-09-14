variable "resource_group_name" {}
variable "storage_account_name" {}

#####################################################################
## Create Resource Group, Storage Account Name
#####################################################################
module "app_backups" {
  source                  = "./modules/azure_blob"
  resource_group_name     = var.resource_group_name
  create_resource_group   = true
  storage_account_name    = var.storage_account_name
  create_storage_account   = true
  storage_container_name  = "app-backups"
}

#####################################################################
## Create ONLY Blob
#####################################################################
module "data_backups" {
  source                  = "./modules/azure_blob"
  resource_group_name     = module.app_backups.ResourceName
  create_resource_group   = false
  storage_account_name    = module.app_backups.AccountName
  create_storage_account   = false
  storage_container_name  = "data-backups"
}

#####################################################################
## Create Minio Values
#####################################################################
module "compose_values" {
  source                  = "./modules/minio_values"
  access_key              = module.app_backups.AccountName
  secret_key              = module.app_backups.AccountKey
  compose_env_path        = "${path.module}/.env"
}

module "helm_chart_values" {
  source                  = "./modules/minio_values"
  access_key              = module.data_backups.AccountName
  secret_key              = module.data_backups.AccountKey
  helm_chart_config_path  = "${path.module}/values/minio_config.yaml"
  helm_chart_secrets_path = "${path.module}/values/minio_secrets.yaml"
}
