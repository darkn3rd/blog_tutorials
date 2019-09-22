#####################################################################
# Variables
#####################################################################
variable "profile" {}
variable "region" {}
variable "database_name" {}
variable "database_user" {}
variable "database_password" {}

#####################################################################
# Modules
#####################################################################
module "core_infra" {
  source   = "./infra"
  profile  = "${var.profile}"
  region   = "${var.region}"
}

module "instances" {
  source   = "./app"
  profile  = "${var.profile}"
  region   = "${var.region}"
  sg_web   = "${module.core_infra.sg_web}"
  sn_web   = "${module.core_infra.sn_pub1}"
}

module "db" {
  source   = "./db"

  profile  = "${var.profile}"
  region   = "${var.region}"

  sg_db    = "${module.core_infra.sg_db}"
  sn_db1   = "${module.core_infra.sn_priv1}"
  sn_db2   = "${module.core_infra.sn_priv2}"

  database_name     = "${var.database_name}"
  database_user     = "${var.database_user}"
  database_password = "${var.database_password}"
}