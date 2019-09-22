#####################################################################
# Output for Webserver
#####################################################################
output "web_public_dns" {
  value = "${aws_instance.my-webserver.public_dns}"
}

output "web_public_ip" {
  value = "${aws_instance.my-webserver.public_ip}"
}
