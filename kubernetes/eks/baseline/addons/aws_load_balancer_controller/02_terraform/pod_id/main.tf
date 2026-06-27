resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set = [
    {
      name  = "clusterName"
      value = var.eks_cluster_name
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "region"
      value = var.eks_region
    },
    {
      name  = "vpcId"
      value = module.eks_network.vpc_id
    }
  ]

  depends_on = [
    aws_eks_pod_identity_association.aws_load_balancer_controller
  ]
}
