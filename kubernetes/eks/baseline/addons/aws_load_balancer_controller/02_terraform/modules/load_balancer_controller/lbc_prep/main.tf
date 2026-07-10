resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = var.role_arn == null ? {} : {
      "eks.amazonaws.com/role-arn" = var.role_arn
    }
  }
}
