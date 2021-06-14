### input variables
variable "domain" {}
variable "name" {}
variable "ip_address" {}

### resources
resource "godaddy_domain_record" "default" {
  domain   = var.domain

  record {
    name = var.name
    type = "A"
    data = var.ip_address
    ttl  = 3600
  }
}
