resource "local_file" "default" {
  count           = var.cluster_config_enabled ? 1 : 0
  content         = local.cluster_config_values
  filename        = var.filename
  file_permission = "0644"
}
