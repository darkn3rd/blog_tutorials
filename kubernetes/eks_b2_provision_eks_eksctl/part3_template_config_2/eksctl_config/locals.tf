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
      for id in data.aws_subnet_ids.private_subnet_ids.ids:
        data.aws_subnet.private_subnets[id].availability_zone => id
    }

    subnet_public = {
      for id in data.aws_subnet_ids.public_subnet_ids.ids:
        data.aws_subnet.public_subnets[id].availability_zone => id
    }
  }

  cluster_config_values = templatefile("${path.module}/cluster_config.yaml.tmpl", local.cluster_config_vars)
}
