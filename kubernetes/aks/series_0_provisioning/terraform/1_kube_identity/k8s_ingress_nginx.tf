locals {
  ingress_nginx_vars = {
    controller_replica_count  = 2
    controller_limit_cpu      = "200m"
    controller_limit_memory   = "1Gi"
    controller_request_cpu    = "100m"
    controller_request_memory = "256Mi"

    enable_default_backend         = true
    default_backend_replica_count  = 2
    default_backend_limit_cpu      = "50m"
    default_backend_limit_memory   = "24Mi"
    default_backend_request_cpu    = "1m"
    default_backend_request_memory = "8Mi"
  }

  ingress_nginx_values = templatefile(
    "${path.module}/templates/ingress_nginx_values.yaml.tmpl",
    local.ingress_nginx_vars
  )
}

##########
# ingress_nginx - helm chart that adds ingress-nginx functionality
##########################
resource "helm_release" "ingress_nginx" {
  count            = var.enable_ingress_nginx ? 1 : 0
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "kube-addons"
  create_namespace = true
  version          = "4.0.2"
  values           = [local.ingress_nginx_values]
}
