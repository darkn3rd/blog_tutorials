variable "resource_group_name" {}
variable "cluster_name" {}

resource "kubernetes_deployment" "hello_kubernetes" {
  metadata {
    name = "hello-kubernetes"
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
            limits {
              cpu    = "250m"
              memory = "128Mi"
            }

            requests {
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
    name = "hello-kubernetes"
  }

  spec {
    port {
      port        = 80
      target_port = "8080"
    }

    selector = {
      app = "hello-kubernetes"
    }

    type = "ClusterIP"
  }
}
