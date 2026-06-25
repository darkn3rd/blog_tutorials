# Fetch the AWS-managed policy document directly
data "aws_eks_cluster" "target" {
  name     = var.eks_cluster_name
  provider = aws.eks_region
}

data "aws_eks_cluster_auth" "target" {
  provider = aws.eks_region
  name     = var.eks_cluster_name
}

data "aws_iam_openid_connect_provider" "target" {
  url      = data.aws_eks_cluster.target.identity[0].oidc[0].issuer
  provider = aws.eks_region
}

data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
}

# Create the trust relationship data for OIDC (IRSA)
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
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
      identifiers = [data.aws_iam_openid_connect_provider.target.arn]
      type        = "Federated"
    }
  }
}
