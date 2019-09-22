#####################################################################
# Output for Webserver
#####################################################################
output "vpc" {
  value     = "${aws_vpc.w1_main.id}"
}

output "sn_pub1" {
  value     = "${aws_subnet.w1_public1.id}"
}

output "sn_pub2" {
  value     = "${aws_subnet.w1_public2.id}"
}

output "sn_priv1" {
  value     = "${aws_subnet.w1_private1.id}"
}

output "sn_priv2" {
  value     = "${aws_subnet.w1_private2.id}"
}
