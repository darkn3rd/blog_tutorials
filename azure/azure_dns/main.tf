module "azure_net" {
  source              = "./azure_net"
  resource_group_name = var.resource_group_name
  location            = var.location
}

module "azure_vm" {
  source              = "./azure_vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = module.azure_net.subnet_id
  image_publisher     = var.image_publisher
  image_offer         = var.image_offer
  image_sku           = var.image_sku
  computer_name       = var.computer_name
  admin_username      = var.admin_username
}

module "godaddy_dns_record" {
  source     = "./godaddy_dns_record"
  domain     = var.domain
  name       = var.computer_name
  ip_address = module.azure_vm.public_ip
}

module "azure_dns_domain" {
  source              = "./azure_dns_domain"
  resource_group_name = var.resource_group_name
  domain              = var.domain
  subdomain_prefix    = var.subdomain_prefix
}

module "azure_dns_record" {
  source              = "./azure_dns_record"
  resource_group_name = var.resource_group_name
  dns_zone_name       = module.azure_dns_domain.dns_zone_name
  name                = var.computer_name
  ip_address          = module.azure_vm.public_ip
}
