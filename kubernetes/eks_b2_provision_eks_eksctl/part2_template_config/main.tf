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
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  instance_type      = "m5.2xlarge"
  public_key_name    = "joaquin"
  filename           = "${path.module}/cluster_config.yaml"
}
