locals {
  vpc_id = data.aws_eks_cluster.target.vpc_config[0].vpc_id
}
