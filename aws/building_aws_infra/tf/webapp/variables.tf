variable "profile" {}
variable "region" {}

# security groups
variable "sg_web" {}
variable "sg_db" {}

# subnets
variable "sn_web" {}
variable "sn_db1" {}
variable "sn_db2" {}

# config artifact
variable "database_name" {}
variable "database_user" {}

# secrets artifact
variable "database_password" {}

# instance key pair
variable "key_name" {}