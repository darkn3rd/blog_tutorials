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
