output "gateway_name" {
  description = "Name of the created Gateway (fetch its address manually, e.g. kubectl get gateway <name> -n <namespace> -o jsonpath='{.status.addresses[0].value}')"
  value       = "${var.app_name}-gw"
}
