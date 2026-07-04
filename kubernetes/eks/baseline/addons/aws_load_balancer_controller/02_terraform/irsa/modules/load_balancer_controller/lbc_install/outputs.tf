output "helm_release_name" {
  description = "Name of the deployed aws-load-balancer-controller Helm release"
  value       = helm_release.aws_lb_controller.name
}
