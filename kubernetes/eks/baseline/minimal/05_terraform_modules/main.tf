data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc_cidr = "192.168.0.0/16"

  azs      = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
  az_count = length(local.azs)

  public_subnets = [
    for i in range(local.az_count) :
    cidrsubnet(local.vpc_cidr, 3, i)
  ]

  private_subnets = [
    for i in range(local.az_count) :
    cidrsubnet(local.vpc_cidr, 3, i + 3)
  ]

  cluster_tags = {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

module "eks_network" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6"

  name = var.eks_cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway = true
  single_nat_gateway = true

  map_public_ip_on_launch = true

  public_subnet_tags = merge(local.cluster_tags, {
    "kubernetes.io/role/elb" = "1"
  })

  private_subnet_tags = merge(local.cluster_tags, {
    "kubernetes.io/role/internal-elb" = "1"
  })

  tags = local.cluster_tags
}

module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.eks_cluster_name
  kubernetes_version = var.eks_version

  endpoint_public_access = true

  vpc_id     = module.eks_network.vpc_id
  subnet_ids = module.eks_network.private_subnets

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
    aws-ebs-csi-driver     = {}
    metrics-server         = {}
  }

  eks_managed_node_groups = {
    ng_1 = {
      name = "ng-1"

      subnet_ids = module.eks_network.private_subnets

      instance_types = ["m5.large"]

      min_size     = 3
      max_size     = 3
      desired_size = 3

      ami_type = "AL2023_x86_64_STANDARD"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"

          ebs = {
            volume_size = 80
            volume_type = "gp3"
            iops        = 3000
            throughput  = 125
          }
        }
      }
    }
  }
}
