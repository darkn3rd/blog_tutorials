#####################################################################
# SECURITY GROUPS
#####################################################################
resource "aws_security_group" "w1-webserver" {
  name        = "webserver"
  description = "Allow HTTP from Anywhere"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    "Name" = "w1-webserver"
    "Site" = "web-one"
  }
}

resource "aws_security_group" "w1-database" {
  name        = "database"
  description = "Allow MySQL/Aurora from WebService"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.w1-webserver.id}"]
    self            = false

  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    "Name" = "w1-database"
    "Site" = "web-one"
  }
}
