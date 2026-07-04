# Mirrors demos/cli: each demo exercises a different aws-load-balancer-controller
# path (Service/NLB, Ingress/ALB, Gateway+TCPRoute/NLB, Gateway+HTTPRoute/ALB).
# Each submodule creates its own namespace if it doesn't already exist.

module "svc_nlb" {
  source = "./modules/demo_svc_nlb"

  namespace = var.svc_nlb_namespace
}

module "ing_alb" {
  source = "./modules/demo_ing_alb"

  namespace = var.ing_alb_namespace
}

module "gw_nlb" {
  source = "./modules/demo_gw_nlb"

  namespace = var.gw_nlb_namespace
}

module "gw_alb" {
  source = "./modules/demo_gw_alb"

  namespace = var.gw_alb_namespace
}
