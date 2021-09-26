locals {
  cert_manager_vars = {
    log_level      = 2
    limit_cpu      = "200m"
    limit_memory   = "256Mi"
    request_cpu    = "100m"
    request_memory = "128Mi"
  }

  cert_manager_issuers_vars = {
    resource_group_name = var.dns_zone_group,
    tenant_id           = data.azurerm_client_config.current.tenant_id,
    subscription_id     = data.azurerm_client_config.current.subscription_id,
    hosted_zone_name    = var.domain,
    acme_issuer_email   = var.acme_issuer_email
  }

  cert_manager_values = templatefile(
    "${path.module}/templates/cert_manager_values.yaml.tmpl",
    local.cert_manager_vars
  )

  cert_manager_issuers_values = templatefile(
    "${path.module}/templates/cert_manager_issuers_values.yaml.tmpl",
    local.cert_manager_issuers_vars
  )

  # enable cert_manager_issuers only if aceme_issuer_email is set
  cert_manager_issuers = var.enable_cert_manager && var.acme_issuer_email != "" ? true : false
}

##########
# cert_manager - helm chart that adds cert-manager functionality
##########################
resource "helm_release" "cert_manager" {
  count            = var.enable_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "kube-addons"
  create_namespace = true
  version          = "1.5.3"
  values           = [local.cert_manager_values]
  depends_on       = [azurerm_role_assignment.attach_dns]
}

##########
# cert_manager_issuers - ClusterIssuers resources used to issue certs across cluster
##########################
resource "helm_release" "cert_manager_issuers" {
  count            = local.cert_manager_issuers ? 1 : 0
  name             = "cert-manager-issuers"
  repository       = "https://charts.itscontained.io"
  chart            = "raw"
  namespace        = "kube-addons"
  create_namespace = true
  version          = "0.2.5"
  values           = [local.cert_manager_issuers_values]
  depends_on       = [helm_release.cert_manager]
}
