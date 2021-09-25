### Local Variables
locals {
  domain_name   = var.subdomain_prefix == "" ? "${var.domain}" : "${var.subdomain_prefix}.${var.domain}"
  dns_zone_name = var.create_dns_zone ? azurerm_dns_zone.default[0].name : data.azurerm_dns_zone.default[0].name
  name_servers  = var.create_dns_zone ? azurerm_dns_zone.default[0].name_servers : data.azurerm_dns_zone.default[0].name_servers
  dns_zone_id   = var.create_dns_zone ? azurerm_dns_zone.default[0].id : data.azurerm_dns_zone.default[0].id
}

### Resources
resource "azurerm_dns_zone" "default" {
  count               = var.create_dns_zone ? 1 : 0
  name                = local.domain_name
  resource_group_name = var.resource_group_name
}

# fetch data if resource is not created
data "azurerm_dns_zone" "default" {
  count               = var.create_dns_zone ? 0 : 1
  name                = local.domain_name
  resource_group_name = var.resource_group_name
}

### Output Variables
output "dns_zone_name" {
  value = local.dns_zone_name
}

output "name_servers" {
  value = local.name_servers
}

output "dns_zone_id" {
  value = local.dns_zone_id
}
