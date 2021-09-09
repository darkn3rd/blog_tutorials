variable "resource_group_name" {}
variable "cluster_name" {}
variable "namespace" { default = "default" }
variable "domain" { default = "" }

locals {
  a_record                = "hello.${var.domain}"
  external_dns_annotation = { "external-dns.alpha.kubernetes.io/hostname" = local.a_record }
  service_annotations     = var.domain != "" ? local.external_dns_annotation : {}
}

resource "kubernetes_namespace" "default" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "hello_kubernetes" {
  metadata {
    name      = "hello-kubernetes"
    namespace = kubernetes_namespace.default.metadata.0.name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "hello-kubernetes"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-kubernetes"
        }
      }

      spec {
        container {
          name  = "hello-kubernetes-basic"
          image = "paulbouwer/hello-kubernetes:1.10"

          port {
            container_port = 8080
          }

          env {
            name = "KUBERNETES_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name = "KUBERNETES_NODE_NAME"

            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          resources {
            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }

            requests = {
              cpu    = "80m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "hello_kubernetes" {
  metadata {
    name        = "hello-kubernetes"
    namespace   = kubernetes_namespace.default.metadata.0.name
    annotations = local.service_annotations
  }

  spec {
    port {
      port        = 80
      target_port = "8080"
    }

    selector = {
      app = kubernetes_deployment.hello_kubernetes.spec[0].template[0].metadata[0].labels.app
    }

    type = "ClusterIP"
  }
}
