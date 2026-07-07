output "sa_name" {
  description = "Name of the aws-load-balancer-controller Kubernetes service account"
  value       = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
}
