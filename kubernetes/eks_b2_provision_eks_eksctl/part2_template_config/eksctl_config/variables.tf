variable "name" {}
variable "region" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}

variable "public_key_name" {}
variable "instance_type" {}

variable "cluster_config_enabled" { default = true }
variable "min_size" { default = 3 }
variable "max_size" { default = 6 }
variable "desired_capacity" { default = 3 }

variable "filename" {}
