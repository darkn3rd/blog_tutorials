### Input Variables
variable "resource_group_name" {
  description = "The resource group name to be imported"
  type        = string
}

variable "domain" {
  description = "The domain name used to create the Azure DNS zone"
  type        = string
}

variable "subdomain_prefix" {
  description = "The subdomain_prefix used to create domain name."
  type        = string
  default     = ""
}

variable "create_dns_zone" {
  description = "Toggle whether or not to create the resource."
  type        = bool
  default     = true
}
