#!/usr/bin/env bash
set -euo pipefail

VPC_ID=$1

[[ $# -eq 1 ]] || {
  echo "Usage: $0 <vpc-id>" >&2
  exit 1
}

echo "=== Network Interfaces ==="
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Status:Status,Description:Description,Requester:RequesterId,Subnet:SubnetId}' \
  --output table

echo "=== NAT Gateways ==="
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[].{NAT:NatGatewayId,State:State,Subnet:SubnetId}' \
  --output table

echo "=== VPC Endpoints ==="
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'VpcEndpoints[].{Endpoint:VpcEndpointId,Service:ServiceName,State:State}' \
  --output table

echo "=== Security Groups ==="
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[].{SG:GroupId,Name:GroupName,Description:Description}' \
  --output table