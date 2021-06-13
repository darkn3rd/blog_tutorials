### Input Variables
variable "resource_group_name" {}
variable "domain" {}
variable "subdomain_prefix" { default = "" }

### Local Variables
locals {
  domain_name = var.subdomain_prefix == "" ? "${var.domain}" : "${var.subdomain_prefix}.${var.domain}"
}

### Resources
resource "azurerm_dns_zone" "default" {
  name                = local.domain_name
  resource_group_name = var.resource_group_name
}

### Output Variables
output "dns_zone_name" {
  value = azurerm_dns_zone.default.name
}
