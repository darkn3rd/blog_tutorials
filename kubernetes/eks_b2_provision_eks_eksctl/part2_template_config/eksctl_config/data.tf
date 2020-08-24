data "aws_subnet" "private0" { id = var.private_subnet_ids[0] }
data "aws_subnet" "private1" { id = var.private_subnet_ids[1] }
data "aws_subnet" "private2" { id = var.private_subnet_ids[2] }
data "aws_subnet" "public0" { id = var.public_subnet_ids[0] }
data "aws_subnet" "public1" { id = var.public_subnet_ids[1] }
data "aws_subnet" "public2" { id = var.public_subnet_ids[2] }
