## Test1: Blob and Storage Account Will Be Created
## Prerequisites:
## - resources group created

module "blob" {
  source                  = "../modules/azure_blob"
  resource_group_name     = "existing-resources"
  create_resource_group   = false
  storage_account_name    = "the3blob1is9after4you"
  storage_container_name  = "more-backups"
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
