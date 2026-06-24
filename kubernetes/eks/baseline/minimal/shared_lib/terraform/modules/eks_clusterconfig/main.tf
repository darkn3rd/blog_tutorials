locals {
  cluster_yaml = templatefile("${path.module}/templates/cluster.yaml.tftpl", {
    cluster_name       = var.eks_cluster_name
    region             = var.eks_region
    version            = var.eks_version
    vpc_id             = var.vpc_id
    public_subnet_ids  = var.public_subnet_ids
    private_subnet_ids = var.private_subnet_ids
    node_subnet_ids    = values(var.private_subnet_ids)
  })
}

resource "local_file" "cluster_yaml" {
  filename = "${path.root}/cluster.yaml"
  content  = local.cluster_yaml
}
