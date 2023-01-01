################
# Virtual Private Cloud
############################
resource "aws_vpc" "my-main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = false
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags {
    Site = "my-web-site"
    Name = "my-vpc"
  }
}

################
# Fetch AZs for the region
############################
data "aws_availability_zones" "available" {}

################
# Public Subnets
############################
resource "aws_subnet" "my-public1" {
  vpc_id                  = "${aws_vpc.my-main.id}"
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = true

  tags {
    Name = "my-public2"
    Site = "my-web-site"
  }
}

resource "aws_subnet" "my-public2" {
  vpc_id                  = "${aws_vpc.my-main.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true

  tags {
    Name = "my-public1"
    Site = "my-web-site"
  }
}

################
# Private Subnets
############################
resource "aws_subnet" "my-private1" {
  vpc_id                  = "${aws_vpc.my-main.id}"
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = true

  tags {
    Name = "my-private1"
    Site = "my-web-site"
  }
}

resource "aws_subnet" "my-private2" {
  vpc_id                  = "${aws_vpc.my-main.id}"
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true

  tags {
    Name = "my-private2"
    Site = "my-web-site"
  }
}

################
# Internet Gateway
############################
resource "aws_internet_gateway" "my-igw" {
  vpc_id = "${aws_vpc.my-main.id}"

  tags = {
    Name = "my-igw"
    Site = "my-web-site"
  }
}

################
# Route Tables + Associations
############################
resource "aws_route_table" "my-rt" {
  vpc_id = "${aws_vpc.my-main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.my-igw.id}"
  }

  tags {
    Site = "my-web-site"
    Name = "my-rt"
  }
}

resource "aws_route_table_association" "my-public1" {
  subnet_id      = "${aws_subnet.my-public1.id}"
  route_table_id = "${aws_route_table.my-rt.id}"
}

resource "aws_route_table_association" "my-public2" {
  subnet_id      = "${aws_subnet.my-public2.id}"
  route_table_id = "${aws_route_table.my-rt.id}"
}