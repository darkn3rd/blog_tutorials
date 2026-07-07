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
      sa_name      = var.sa_name
    })
  ]
}
