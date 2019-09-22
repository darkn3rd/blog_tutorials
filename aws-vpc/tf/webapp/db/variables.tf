#####################################################################
# Variables
#####################################################################

# security group
variable "sg_db" {}

# private subnets
variable "sn_db1" {}
variable "sn_db2" {}

# database config/secret artifacts
variable "database_name" {}
variable "database_user" {}
variable "database_password" {}
