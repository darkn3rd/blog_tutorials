output "role_arn" {
  description = "ARN of the IAM role used by the aws-load-balancer-controller service account"
  value       = module.lbc_auth.role_arn
}

output "sa_name" {
  description = "Name of the aws-load-balancer-controller Kubernetes service account"
  value       = module.lbc_prep.sa_name
}
