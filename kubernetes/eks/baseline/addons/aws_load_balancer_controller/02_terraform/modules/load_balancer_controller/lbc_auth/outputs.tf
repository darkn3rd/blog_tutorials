output "role_arn" {
  description = "ARN of the IAM role used by the aws-load-balancer-controller service account"
  value       = aws_iam_role.aws_load_balancer_controller.arn
  # ensure the policy attachment (and, for pod identity, the association) exist before anything downstream relies on this ARN
  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
    aws_eks_pod_identity_association.aws_load_balancer_controller,
  ]
}
