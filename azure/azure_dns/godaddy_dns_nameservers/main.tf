### input variables
variable "domain" {}
variable "name_servers" {}

resource "godaddy_domain_record" "default" {
  domain   = var.domain
  nameservers = var.name_servers
}
