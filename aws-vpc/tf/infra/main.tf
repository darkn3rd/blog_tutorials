
#####################################################################
# VIRTUAL PRIVATE CLOUD
#####################################################################
resource "aws_vpc" "w1_main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = false
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags {
    Site = "web-one"
    Name = "w1-vpc"
  }
}

#####################################################################
# SUBNETS
#####################################################################
data "aws_availability_zones" "available" {}

resource "aws_subnet" "w1_public1" {
  vpc_id                  = "${aws_vpc.w1_main.id}"
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = true

  tags {
    "Name" = "w1-public2"
    "Site" = "web-one"
  }
}

resource "aws_subnet" "w1_public2" {
  vpc_id                  = "${aws_vpc.w1_main.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true

  tags {
    "Name" = "w1-public1"
    "Site" = "web-one"
  }
}

resource "aws_subnet" "w1_private1" {
  vpc_id                  = "${aws_vpc.w1_main.id}"
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = true

  tags {
    "Name" = "w1-private1"
    "Site" = "web-one"
  }
}

resource "aws_subnet" "w1_private2" {
  vpc_id                  = "${aws_vpc.w1_main.id}"
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true

  tags {
    "Name" = "w1-private2"
    "Site" = "web-one"
  }
}

#####################################################################
# INTERNET GATEWAY
#####################################################################
resource "aws_internet_gateway" "w1_igw" {
  vpc_id = "${aws_vpc.w1_main.id}"

  tags = {
    "Name" = "w1-igw"
    "Site" = "web-one"
  }
}

#####################################################################
# ROUTE TABLES
#####################################################################
resource "aws_route_table" "w1_rt" {
  vpc_id = "${aws_vpc.w1_main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.w1_igw.id}"
  }

  tags {
    "Site" = "web-one"
    "Name" = "w1-rt"
  }
}

resource "aws_route_table_association" "w1_public1" {
  subnet_id      = "${aws_subnet.w1_public1.id}"
  route_table_id = "${aws_route_table.w1_rt.id}"
}

resource "aws_route_table_association" "w1_public2" {
  subnet_id      = "${aws_subnet.w1_public2.id}"
  route_table_id = "${aws_route_table.w1_rt.id}"
}
