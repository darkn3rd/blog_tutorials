output "hostname" {
  description = "DNS hostname of the provisioned NLB (null until AWS finishes provisioning it - check again with `terraform refresh`)"
  value       = module.nginx.hostname
}
