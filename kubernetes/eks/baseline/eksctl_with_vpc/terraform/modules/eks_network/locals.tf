

locals {
  name     = var.eks_cluster_name
  vpc_cidr = "192.168.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))

  public_subnets = {
    for index, az in local.azs :
    az => cidrsubnet(local.vpc_cidr, 3, index)
  }

  private_subnets = {
    for index, az in local.azs :
    az => cidrsubnet(local.vpc_cidr, 3, index + 4)
  }

  common_tags = {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}
