resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = var.role_arn
    }
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/values.yaml.tmpl", {
      cluster_name = var.eks_cluster_name
      vpc_id       = var.vpc_id
      region       = var.eks_region
      sa_name      = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
    })
  ]

  # Ensure the service account annotation and CRDs exist before Helm tries to initialize the pods
  depends_on = [
    kubernetes_service_account_v1.aws_load_balancer_controller,
    kubectl_manifest.gateway_api,
    kubectl_manifest.aws_lbc_gateway
  ]
}
