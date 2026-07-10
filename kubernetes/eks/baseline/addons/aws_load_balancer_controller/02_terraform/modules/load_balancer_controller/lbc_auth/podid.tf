# Pod-Identity-specific: builds the trust policy that lets the EKS Pod
# Identity Agent assume the role in role.tf, then associates that role with
# the controller's ServiceAccount. Requires the EKS Pod Identity Agent addon
# to already be installed on the cluster -- unlike IRSA, no OIDC provider
# lookup is needed.
data "aws_iam_policy_document" "podid_assume_role" {
  count = var.auth_mode == "pod_identity" ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      identifiers = ["pods.eks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  count = var.auth_mode == "pod_identity" ? 1 : 0

  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn
}
