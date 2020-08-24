#####################################################################
# VPC
#####################################################################
variable "region" {}
variable "name" {}

module "vpc" {
  source = "./vpc"
  name   = var.name
  region = var.region
}

module "config" {
  source             = "./eksctl_config"
  name               = var.name
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  instance_type      = "m5.2xlarge"
  public_key_name    = "joaquin"
  filename           = "${path.module}/cluster_config.yaml"
}
