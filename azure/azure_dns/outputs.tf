output "tls_private_key" {
  value     = module.azure_vm.tls_private_key
  sensitive = true
}

output "public_ip" {
  value = module.azure_vm.public_ip
}
