

locals {
  name     = var.eks_cluster_name
  vpc_cidr = "192.168.0.0/16"

  azs = ["us-east-2a", "us-east-2b", "us-east-2c"]

  public_subnets = {
    us-east-2a = "192.168.32.0/19"
    us-east-2b = "192.168.64.0/19"
    us-east-2c = "192.168.0.0/19"
  }

  private_subnets = {
    us-east-2a = "192.168.128.0/19"
    us-east-2b = "192.168.160.0/19"
    us-east-2c = "192.168.96.0/19"
  }

  common_tags = {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}
