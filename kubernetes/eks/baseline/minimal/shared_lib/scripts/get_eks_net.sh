#!/usr/bin/env bash
set -euo pipefail

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_REGION:?EKS_REGION is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"

aws_cli() {
  aws --profile "$AWS_PROFILE" --region "$EKS_REGION" "$@"
}

echo "=== VPCs ==="
VPC_ID=$(aws_cli ec2 describe-subnets \
  --filters "Name=tag:kubernetes.io/cluster/${EKS_CLUSTER_NAME},Values=shared,owned" \
  --query 'Subnets[0].VpcId' \
  --output text)

aws_cli ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query 'Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table

# aws_cli ec2 describe-vpcs \
#   --filters "Name=tag:kubernetes.io/cluster/${EKS_CLUSTER_NAME},Values=shared,owned" \
#   --query 'Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}' \
#   --output table

echo "=== Subnets ==="
aws_cli ec2 describe-subnets \
  --filters "Name=tag:kubernetes.io/cluster/${EKS_CLUSTER_NAME},Values=shared,owned" \
  --query 'Subnets[].{AZ:AvailabilityZone,CIDR:CidrBlock,SubnetId:SubnetId,Name:Tags[?Key==`Name`]|[0].Value,ELB:Tags[?Key==`kubernetes.io/role/elb`]|[0].Value,InternalELB:Tags[?Key==`kubernetes.io/role/internal-elb`]|[0].Value}' \
  --output table

echo "=== Internet Gateways ==="
# aws_cli ec2 describe-internet-gateways \
#   --filters "Name=tag:kubernetes.io/cluster/${EKS_CLUSTER_NAME},Values=shared,owned" \
#   --query 'InternetGateways[].{IGW:InternetGatewayId,Name:Tags[?Key==`Name`]|[0].Value,VPC:Attachments[0].VpcId}' \
#   --output table

aws_cli ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[].{IGW:InternetGatewayId,Name:Tags[?Key==`Name`]|[0].Value,VPC:Attachments[0].VpcId}' \
  --output table

echo "=== NAT Gateways ==="
# aws_cli ec2 describe-nat-gateways \
#   --filter "Name=tag:kubernetes.io/cluster/${EKS_CLUSTER_NAME},Values=shared,owned" \
#   --query 'NatGateways[].{NAT:NatGatewayId,State:State,Subnet:SubnetId,Name:Tags[?Key==`Name`]|[0].Value}' \
#   --output table

aws_cli ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[].{NAT:NatGatewayId,State:State,Subnet:SubnetId,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table

echo "=== Route Tables ==="
# aws_cli ec2 describe-route-tables \
#   --filters "Name=tag:kubernetes.io/cluster/${EKS_CLUSTER_NAME},Values=shared,owned" \
#   --query 'RouteTables[].{RouteTable:RouteTableId,Name:Tags[?Key==`Name`]|[0].Value,Associations:length(Associations),Routes:length(Routes)}' \
#   --output table

aws_cli ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].{RouteTable:RouteTableId,Name:Tags[?Key==`Name`]|[0].Value,Associations:length(Associations),Routes:length(Routes)}' \
  --output table