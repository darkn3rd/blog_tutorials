# "default" always exists in every cluster and can't be created or deleted
resource "kubernetes_namespace_v1" "this" {
  count = var.namespace == "default" ? 0 : 1

  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.app_name
    namespace = var.namespace
    labels    = { app = var.app_name }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = var.app_name }
    }

    template {
      metadata {
        labels = { app = var.app_name }
      }

      spec {
        container {
          name  = var.app_name
          image = var.image

          port {
            container_port = 80
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name        = var.app_name
    namespace   = var.namespace
    labels      = { app = var.app_name }
    annotations = var.service_annotations
  }

  spec {
    type = var.service_type

    selector = { app = var.app_name }

    port {
      port        = 80
      target_port = 80
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}
