output "hostname" {
  description = "DNS hostname of the provisioned ALB (null until AWS finishes provisioning it - check again with `terraform refresh`)"
  value       = try(kubernetes_ingress_v1.this.status[0].load_balancer[0].ingress[0].hostname, null)
}
