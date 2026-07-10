output "svc_nlb_hostname" {
  description = "NLB hostname for the Service demo"
  value       = module.svc_nlb.hostname
}

output "ing_alb_hostname" {
  description = "ALB hostname for the Ingress demo"
  value       = module.ing_alb.hostname
}

output "gw_nlb_gateway_name" {
  description = "Gateway name for the Gateway+TCPRoute demo"
  value       = module.gw_nlb.gateway_name
}

output "gw_alb_gateway_name" {
  description = "Gateway name for the Gateway+HTTPRoute demo"
  value       = module.gw_alb.gateway_name
}
