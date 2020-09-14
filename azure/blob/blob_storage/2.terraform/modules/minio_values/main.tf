#####################################################################
## Resources
#####################################################################
resource "local_file" "compose_env" {
  count           = var.compose_env_path != "" ? 1 : 0
  content         = local.compose_env
  filename        = var.compose_env_path
  file_permission = "0644"
}

resource "local_file" "s3cfg" {
  count           = var.s3cfg_path != "" ? 1 : 0
  content         = local.s3cfg
  filename        = var.s3cfg_path
  file_permission = "0644"
}

resource "local_file" "helm_chart_config" {
  count           = var.helm_chart_config_path != "" ? 1 : 0
  content         = local.helm_chart_config
  filename        = var.helm_chart_config_path
  file_permission = "0644"
}

resource "local_file" "helm_chart_secrets" {
  count           = var.helm_chart_secrets_path != "" ? 1 : 0
  content         = local.helm_chart_secrets
  filename        = var.helm_chart_secrets_path
  file_permission = "0644"
}
