locals {
  vpc_id = data.aws_eks_cluster.target.vpc_config[0].vpc_id
  # use to pass to the lbc_irsa submodule to look up the OIDC provider and build the IRSA trust policy
  oidc_issuer_url = data.aws_eks_cluster.target.identity[0].oidc[0].issuer
}
