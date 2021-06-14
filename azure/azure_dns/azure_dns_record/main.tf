### Input Variables
variable "resource_group_name" {}
variable "dns_zone_name" {}
variable "name" {}
variable "ip_address" {}

### Resources
resource "azurerm_dns_a_record" "default" {
  name                = var.name
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.ip_address]
}
