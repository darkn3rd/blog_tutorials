output "tls_private_key" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

output "public_ip" {
  value = azurerm_public_ip.default.ip_address
}
