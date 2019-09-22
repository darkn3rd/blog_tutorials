#####################################################################
# Output for Webserver
#####################################################################
output "database_endpoint" {
  value = "${aws_db_instance.my-db.endpoint}"
}
