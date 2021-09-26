locals {
  cert_manager_vars = {
    log_level = 2
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
    local.cert_manager_issuer_vars
  )

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
}

##########
# cert_manager_issuers - ClusterIssuers resources used to issue certs across cluster
##########################
resource "helm_release" "cert_manager_issuers" {
  count            = var.enable_cert_manager ? 1 : 0
  name             = "cert_manager_issuers"
  repository       = "https://charts.itscontained.io"
  chart            = "itscontained"
  namespace        = "kube-addons"
  create_namespace = true
  version          = "0.2.5"
  values           = [local.cert_manager_issuer_values]
}

