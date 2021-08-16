# required inputs
variable "resource_group_name" {}
variable "dns_prefix" {}
variable "name" {}

# default inputs
variable "network_plugin" { default = "kubenet" }
variable "network_policy" { default = "" }
variable "vm_size" { default = "Standard_D2_v2" }
variable "agent_count" { default = 3 }
variable "ssh_public_key" { default = "~/.ssh/id_rsa.pub" }
