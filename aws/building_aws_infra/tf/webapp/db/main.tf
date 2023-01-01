resource "aws_db_subnet_group" "my-dbsg" {
  name        = "my-dbsg"
  description = "my-dbsg"
  subnet_ids  = ["${var.sn_db1}", "${var.sn_db2}"]

  tags = {
    "Name" = "my-dbsg"
    "Site" = "my-web-site"
  }
}

resource "aws_db_instance" "my-db" {
  identifier        = "my-db"
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "mysql"
  engine_version    = "5.6.40"
  instance_class    = "db.t2.micro"

  name     = "${var.database_name}"
  username = "${var.database_user}"
  password = "${var.database_password}"

  parameter_group_name   = "default.mysql5.6"
  db_subnet_group_name   = "${aws_db_subnet_group.my-dbsg.id}"
  vpc_security_group_ids = ["${var.sg_db}"]

  # set these for dev db
  backup_retention_period = 0

  # required for deleting
  skip_final_snapshot       = true
  final_snapshot_identifier = "Ignore"

  tags = {
    "Name" = "my-db"
    "Site" = "my-web-site"
  }
}