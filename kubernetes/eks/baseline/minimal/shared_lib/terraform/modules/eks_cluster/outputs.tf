output "cluster_summary" {
  value = {
    cluster_name       = aws_eks_cluster.this.name
    cluster_version    = aws_eks_cluster.this.version
    cluster_status     = aws_eks_cluster.this.status
    cluster_endpoint   = aws_eks_cluster.this.endpoint
    cluster_role_arn   = aws_iam_role.cluster.arn
    cluster_sg_id      = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    control_plane_sg   = aws_security_group.control_plane.id
    shared_node_sg     = aws_security_group.shared_node.id
    node_group_name    = aws_eks_node_group.ng_1.node_group_name
    node_role_arn      = aws_iam_role.node.arn
    private_subnet_ids = values(var.private_subnet_ids)
    public_subnet_ids  = values(var.public_subnet_ids)
    addons = {
      vpc_cni            = aws_eks_addon.vpc_cni.addon_version
      coredns            = aws_eks_addon.coredns.addon_version
      kube_proxy         = aws_eks_addon.kube_proxy.addon_version
      ebs_csi            = aws_eks_addon.ebs_csi.addon_version
      pod_identity_agent = aws_eks_addon.pod_identity_agent.addon_name
    }
  }
}
