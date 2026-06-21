output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  value = { for az, subnet in aws_subnet.private : az => subnet.id }
}

# Add these for modules/resources that only need lists.
output "public_subnet_id_list" {
  value = values(aws_subnet.public)[*].id
}

output "private_subnet_id_list" {
  value = values(aws_subnet.private)[*].id
}

output "all_subnet_id_list" {
  value = concat(
    values(aws_subnet.public)[*].id,
    values(aws_subnet.private)[*].id
  )
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.this.id
}

output "network_summary" {
  value = {
    vpc_id             = aws_vpc.this.id
    internet_gateway   = aws_internet_gateway.this.id
    nat_gateway        = aws_nat_gateway.this.id
    public_subnets     = values(aws_subnet.public)[*].id
    private_subnets    = values(aws_subnet.private)[*].id
  }
}
