output "vpc" {
  value = "${aws_vpc.my-main.id}"
}

output "sn_pub1" {
  value = "${aws_subnet.my-public1.id}"
}

output "sn_pub2" {
  value = "${aws_subnet.my-public2.id}"
}

output "sn_priv1" {
  value = "${aws_subnet.my-private1.id}"
}

output "sn_priv2" {
  value = "${aws_subnet.my-private2.id}"
}