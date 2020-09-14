## Test1: Only Blob is created
## Prerequisites:
## - resources group created
## - storage account already exists
## - Role to Access Storage Account setup

module "blob" {
  source                  = "../modules/azure_blob"
  resource_group_name     = "my-superfun-resources"
  create_resource_group   = false
  storage_account_name    = "my0new0unique0storage"
  create_storage_account   = false
  storage_container_name  = "my-backups"
}

module "minio_values" {
  source                  = "../modules/minio_values"
  access_key              = module.blob.AccountName
  secret_key              = module.blob.AccountKey
  compose_env_path        = "${path.module}/.env"
  s3cfg_path              = "${path.module}/values/s3cfg"
  helm_chart_config_path  = "${path.module}/values/minio_config.yaml"
  helm_chart_secrets_path = "${path.module}/values/minio_secrets.yaml"
}
