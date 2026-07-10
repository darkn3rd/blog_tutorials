# type=LoadBalancer + these annotations provision an internet-facing NLB
module "nginx" {
  source = "../demo_nginx"

  namespace = var.namespace
  app_name  = var.app_name
  image     = var.image

  service_type = "LoadBalancer"
  service_annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
  }
}
