#####################################################################
# Modules
#####################################################################
module "network" {
  source   = "./net"
}

module "security" {
  source   = "./sec"
  vpc_id   = "${module.network.vpc}"
}
