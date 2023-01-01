module "instances" {
  source = "./app"

  sg_web   = "${var.sg_web}"
  sn_web   = "${var.sn_web}"
  key_name = "${var.key_name}"
}

module "db" {
  source = "./db"

  sg_db  = "${var.sg_db}"
  sn_db1 = "${var.sn_db1}"
  sn_db2 = "${var.sn_db2}"

  database_name     = "${var.database_name}"
  database_user     = "${var.database_user}"
  database_password = "${var.database_password}"
}
