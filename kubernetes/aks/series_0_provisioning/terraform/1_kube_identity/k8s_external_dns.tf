locals {
  external_dns_vars = {
    resource_group  = var.dns_zone_group
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    domain          = var.domain
    log_level       = "debug"

    limit_cpu      = "200m"
    limit_memory   = "256Mi"
    request_cpu    = "100m"
    request_memory = "128Mi"
  }

  external_dns_values = templatefile(
    "${path.module}/templates/external_dns_values.yaml.tmpl",
    local.external_dns_vars
  )
}

##########
# external_dns - helm chart that adds external-dns functionality
##########################
resource "helm_release" "external_dns" {
  count            = var.enable_external_dns ? 1 : 0
  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  namespace        = "kube-addons"
  create_namespace = true
  version          = "5.4.5"
  values           = [local.external_dns_values]
  depends_on       = [azurerm_role_assignment.attach_dns]
}
