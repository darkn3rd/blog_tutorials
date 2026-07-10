module "nginx" {
  source = "../demo_nginx"

  namespace = var.namespace
  app_name  = var.app_name
  image     = var.image
}

# Cluster-scoped: only one instance of this module should exist per cluster
resource "kubectl_manifest" "gateway_class" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = var.gateway_class_name
    }
    spec = {
      controllerName = "gateway.k8s.aws/nlb"
    }
  })
}

resource "kubectl_manifest" "gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "${var.app_name}-gateway"
      namespace = var.namespace
    }
    spec = {
      gatewayClassName = var.gateway_class_name
      infrastructure = {
        parametersRef = {
          group = "gateway.k8s.aws"
          kind  = "LoadBalancerConfiguration"
          name  = "${var.app_name}-lb-config"
        }
      }
      listeners = [
        {
          name     = "tcp-80"
          protocol = "TCP"
          port     = 80
          allowedRoutes = {
            namespaces = { from = "Same" }
            kinds      = [{ kind = "TCPRoute" }]
          }
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.gateway_class, module.nginx]
}

resource "kubectl_manifest" "tcp_route" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1alpha2"
    kind       = "TCPRoute"
    metadata = {
      name      = "${var.app_name}-route"
      namespace = var.namespace
    }
    spec = {
      parentRefs = [
        {
          name        = "${var.app_name}-gateway"
          sectionName = "tcp-80"
        }
      ]
      rules = [
        {
          backendRefs = [
            {
              name = module.nginx.service_name
              kind = "Service"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.gateway]
}

resource "kubectl_manifest" "lb_config" {
  yaml_body = yamlencode({
    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "LoadBalancerConfiguration"
    metadata = {
      name      = "${var.app_name}-lb-config"
      namespace = var.namespace
    }
    spec = {
      scheme = "internet-facing"
    }
  })

  depends_on = [module.nginx]
}

resource "kubectl_manifest" "tg_config" {
  yaml_body = yamlencode({
    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "TargetGroupConfiguration"
    metadata = {
      name      = "${var.app_name}-tg-config"
      namespace = var.namespace
    }
    spec = {
      targetReference = {
        group = ""
        kind  = "Service"
        name  = module.nginx.service_name
      }
      defaultConfiguration = {
        targetType = "ip"
      }
    }
  })

  depends_on = [module.nginx]
}
