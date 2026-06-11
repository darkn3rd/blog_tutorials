locals {
  cluster_yaml = templatefile("${path.module}/templates/cluster.yaml.tftpl", {
    cluster_name       = var.eks_cluster_name
    region             = var.eks_region
    version            = var.eks_version
    vpc_id             = aws_vpc.this.id
    public_subnet_ids  = { for az, subnet in aws_subnet.public : az => subnet.id }
    private_subnet_ids = { for az, subnet in aws_subnet.private : az => subnet.id }
    node_subnet_ids    = values(aws_subnet.private)[*].id
  })
}

resource "local_file" "cluster_yaml" {
  filename = "${path.module}/cluster.yaml"
  content  = local.cluster_yaml
}
