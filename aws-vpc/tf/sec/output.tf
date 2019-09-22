#####################################################################
# Output for Webserver
#####################################################################
output "sg_web" {
  value     = "${aws_security_group.w1-webserver.id}"
}

output "sg_db" {
  value     = "${aws_security_group.w1-database.id}"
}
