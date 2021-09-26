variable "resource_group_name" {}
variable "cluster_name" {}
variable "namespace" { default = "default" }
variable "domain" { default = "" }

variable "service_type" { default = "ClusterIP" }

variable "enable_ingress" { default = false }
variable "ingress_class" { default = "nginx" }
variable "enable_tls" { default = false }
variable "cluster_issuer" { default = "" }

locals {
  a_record = "hello.${var.domain}"

  # service 
  external_dns_annotation        = { "external-dns.alpha.kubernetes.io/hostname" = local.a_record }
  enable_external_dns_annotation = var.service_type == "LoadBalancer" && var.domain != "" && var.enable_ingress == false ? true : false
  service_annotations            = var.domain != "" && local.enable_external_dns_annotation ? local.external_dns_annotation : {}

  # ingress
  ingress_class_annotation  = { "kubernetes.io/ingress.class" = var.ingress_class }
  cluster_issuer_annotation = var.domain != "" && var.cluster_issuer != "" && var.enable_tls ? { "cert-manager.io/cluster-issuer" = var.cluster_issuer } : {}
  ingress_annotations       = merge(local.ingress_class_annotation, local.cluster_issuer_annotation)
}

resource "kubernetes_namespace" "default" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "default" {
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
              field_ref { field_path = "metadata.namespace" }
            }
          }

          env {
            name = "KUBERNETES_NODE_NAME"
            value_from {
              field_ref { field_path = "spec.nodeName" }
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

resource "kubernetes_service" "default" {
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
      app = kubernetes_deployment.default.spec[0].template[0].metadata[0].labels.app
    }

    type = var.service_type
  }
}

resource "kubernetes_ingress" "default" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name        = "hello-kubernetes"
    namespace   = kubernetes_namespace.default.metadata.0.name
    annotations = local.ingress_annotations
  }

  spec {
    dynamic "tls" {
      for_each = var.enable_tls ? { include = "block" } : {}
      content {
        hosts       = [local.a_record]
        secret_name = "tls-secret"
      }
    }

    rule {
      host = local.a_record
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.default.metadata[0].name
            service_port = kubernetes_service.default.spec[0].port[0].port
          }
        }
      }
    }
  }

}