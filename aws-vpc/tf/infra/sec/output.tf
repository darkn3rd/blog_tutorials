#####################################################################
# Output for Webserver
#####################################################################
output "sg_web" {
  value = "${aws_security_group.my-webserver.id}"
}

output "sg_db" {
  value = "${aws_security_group.my-database.id}"
}
