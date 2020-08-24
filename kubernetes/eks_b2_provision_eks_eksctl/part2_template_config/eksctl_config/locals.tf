locals {
  cluster_config_vars = {
    cluster_name     = var.name
    region           = var.region
    public_key_name  = var.public_key_name
    instance_type    = var.instance_type
    min_size         = var.min_size
    max_size         = var.max_size
    desired_capacity = var.desired_capacity

    subnet_private = {
      (data.aws_subnet.private0.availability_zone) = var.private_subnet_ids[0]
      (data.aws_subnet.private1.availability_zone) = var.private_subnet_ids[1]
      (data.aws_subnet.private2.availability_zone) = var.private_subnet_ids[2]
    }

    subnet_public = {
      (data.aws_subnet.public0.availability_zone) = var.public_subnet_ids[0]
      (data.aws_subnet.public1.availability_zone) = var.public_subnet_ids[1]
      (data.aws_subnet.public2.availability_zone) = var.public_subnet_ids[2]
    }

  }

  cluster_config_values = templatefile("${path.module}/cluster_config.yaml.tmpl", local.cluster_config_vars)
}
