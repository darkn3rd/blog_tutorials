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
      controllerName = "gateway.k8s.aws/alb"
    }
  })
}

resource "kubectl_manifest" "gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "${var.app_name}-gw"
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
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = { from = "Same" }
          }
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.gateway_class, module.nginx]
}

resource "kubectl_manifest" "http_route" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${var.app_name}-route"
      namespace = var.namespace
    }
    spec = {
      hostnames = [var.hostname]
      parentRefs = [
        {
          name        = "${var.app_name}-gw"
          sectionName = "http"
        }
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = module.nginx.service_name
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
      defaultConfiguration = {
        targetType = "ip"
        healthCheckConfig = {
          healthCheckProtocol = "HTTP"
          healthCheckPort     = "80"
          healthCheckPath     = "/"
        }
      }
      targetReference = {
        group = ""
        kind  = "Service"
        name  = module.nginx.service_name
      }
    }
  })

  depends_on = [module.nginx]
}
