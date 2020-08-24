data "aws_subnet_ids" "private_subnet_ids" {
  vpc_id = var.vpc_id

  filter {
    name   = "tag:kubernetes.io/cluster/${var.name}"
    values = ["shared"]
  }

  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = [1]
  }
}

data "aws_subnet_ids" "public_subnet_ids" {
  vpc_id = var.vpc_id

  filter {
    name   = "tag:kubernetes.io/cluster/${var.name}"
    values = ["shared"]
  }

  filter {
    name   = "tag:kubernetes.io/role/elb"
    values = [1]
  }
}

data "aws_subnet" "private_subnets" {
  for_each = data.aws_subnet_ids.private_subnet_ids.ids
  id       = each.value
}

data "aws_subnet" "public_subnets" {
  for_each = data.aws_subnet_ids.public_subnet_ids.ids
  id       = each.value
}
