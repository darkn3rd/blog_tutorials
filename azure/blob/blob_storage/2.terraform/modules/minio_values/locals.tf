#####################################################################
## Locals
#####################################################################
locals {
  minio_vars = {
    accessKey  = var.access_key
    secretKey  = var.secret_key
    tag        = "RELEASE.2020-09-08T23-05-18Z"
    replicas   = var.replicas
    minio_host = var.minio_host
  }

  helm_chart_config  = templatefile("${path.module}/values.minio_config.yaml.tmpl", local.minio_vars)
  helm_chart_secrets = templatefile("${path.module}/values.minio_secrets.yaml.tmpl", local.minio_vars)
  compose_env        = templatefile("${path.module}/minio.env.tmpl", local.minio_vars)
  s3cfg              = templatefile("${path.module}/s3cfg.tmpl", local.minio_vars)
}
