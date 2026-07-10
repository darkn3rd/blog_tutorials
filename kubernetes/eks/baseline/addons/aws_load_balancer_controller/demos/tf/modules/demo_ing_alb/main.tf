module "nginx" {
  source = "../demo_nginx"

  namespace = var.namespace
  app_name  = var.app_name
  image     = var.image
}

# These annotations provision an internet-facing ALB
resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = var.app_name
    namespace = var.namespace

    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = module.nginx.service_name

              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [module.nginx]
}
