output "role_arn" {
  description = "ARN of the IAM role associated with the aws-load-balancer-controller service account"
  value       = module.lbc_setup.role_arn
}

output "helm_release_name" {
  description = "Name of the deployed aws-load-balancer-controller Helm release"
  value       = module.lbc_install.helm_release_name
}
