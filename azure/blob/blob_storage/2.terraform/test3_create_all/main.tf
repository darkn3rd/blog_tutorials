module "blob" {
  source                  = "../modules/azure_blob"
  storage_container_name  = "the1adventures2blobs4fun"
  resource_group_name     = "the1adventures2blobs4fun"
  storage_account_name    = "the1adventures2blobs4fun"
  resource_group_location = "eastus2"
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
