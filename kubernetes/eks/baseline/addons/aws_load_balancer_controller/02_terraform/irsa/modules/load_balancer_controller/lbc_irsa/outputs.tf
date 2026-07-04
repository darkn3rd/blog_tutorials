output "role_arn" {
  description = "ARN of the IAM role assumed by the aws-load-balancer-controller service account"
  value       = aws_iam_role.aws_load_balancer_controller.arn
  # ensure the policy is actually attached before anything downstream relies on this ARN
  depends_on = [aws_iam_role_policy_attachment.aws_load_balancer_controller]
}
