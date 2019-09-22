#####################################################################
# Output Network Infrastructure
#####################################################################
output "vpc" {
  value     = "${module.network.vpc}"
}

output "sn_pub1" {
  value     = "${module.network.sn_pub1}"
}

output "sn_pub2" {
  value     = "${module.network.sn_pub2}"
}

output "sn_priv1" {
  value     = "${module.network.sn_priv1}"
}

output "sn_priv2" {
  value     = "${module.network.sn_priv2}"
}


#####################################################################
# Output Security Groups
#####################################################################
output "sg_web" {
  value     = "${module.security.sg_web}"
}

output "sg_db" {
  value     = "${module.security.sg_db}"
}
