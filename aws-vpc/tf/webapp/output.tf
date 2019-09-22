#####################################################################
# Output for Webserver
#####################################################################
output "database_endpoint" {
  value = "${module.db.database_endpoint}"
}

output "web_public_dns" {
  value = "${module.instances.web_public_dns}"
}

output "web_public_ip" {
  value = "${module.instances.web_public_ip}"
}
