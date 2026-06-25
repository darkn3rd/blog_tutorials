locals {
  # use to pass to data sources or verify issurs
  oidc_issuer_url = data.aws_eks_cluster.target.identity[0].oidc[0].issuer
  # use for stripped IAM condition variables
  oidc_provider_path = replace(local.oidc_issuer_url, "https://", "")

  vpc_id = data.aws_eks_cluster.target.vpc_config[0].vpc_id
}
