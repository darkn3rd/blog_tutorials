variable "resource_group_name" {}
variable "location" {}

variable "image_publisher" { default = "Canonical" }
variable "image_offer" { default = "UbuntuServer" }
variable "image_sku" { default = "18.04-LTS" }
variable "image_version" { default = "latest" }

variable "computer_name" {}
variable "admin_username" {}
