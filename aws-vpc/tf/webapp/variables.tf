#####################################################################
# Variables
#####################################################################

# aws profile variables
variable "profile" {}
variable "region" {}

# database config/secret artifacts
variable "database_name" {}
variable "database_user" {}
variable "database_password" {}

# web security groups and subnets
variable "sg_web" {}
variable "sn_web" {}

# database security groups and subnets
variable "sg_db" {}
variable "sn_db1" {}
variable "sn_db2" {}
