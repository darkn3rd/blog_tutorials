# IRSA-specific: looks up the cluster's IAM OIDC provider and builds the
# trust policy that lets the aws-load-balancer-controller ServiceAccount
# assume the role in role.tf via IRSA.
data "aws_iam_openid_connect_provider" "target" {
  count = var.auth_mode == "irsa" ? 1 : 0

  url = var.oidc_issuer_url
}

locals {
  # stripped OIDC issuer, used for IAM condition variables
  oidc_provider_path = var.auth_mode == "irsa" ? replace(var.oidc_issuer_url, "https://", "") : null
}

data "aws_iam_policy_document" "irsa_assume_role" {
  count = var.auth_mode == "irsa" ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_path}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_path}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [data.aws_iam_openid_connect_provider.target[0].arn]
      type        = "Federated"
    }
  }
}
