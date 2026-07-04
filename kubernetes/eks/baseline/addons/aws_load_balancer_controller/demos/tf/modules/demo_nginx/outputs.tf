output "namespace" {
  description = "Namespace the app was deployed into"
  value       = var.namespace
}

output "service_name" {
  description = "Name of the backing Service"
  value       = kubernetes_service_v1.this.metadata[0].name
}

output "hostname" {
  description = "DNS hostname of the provisioned load balancer, if service_type is LoadBalancer (null until AWS finishes provisioning it - check again with `terraform refresh`)"
  value       = try(kubernetes_service_v1.this.status[0].load_balancer[0].ingress[0].hostname, null)
}
