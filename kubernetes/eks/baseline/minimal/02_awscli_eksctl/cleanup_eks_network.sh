#!/usr/bin/env bash
set -euo pipefail

source ../shared_lib/shell_lib/common.sh
source ../shared_lib/shell_lib/aws.sh

[[ -f ./vpc-outputs.env ]] || die "vpc-outputs.env not found in current directory"
source ./vpc-outputs.env

# Shell parameter expansion:
# Fail if EKS_REGION is unset or empty.
# Equivalent to:
#   require_env EKS_REGION
# Using the POSIX shell idiom for reference.
: "${EKS_REGION:?EKS_REGION is required}"
: "${VPC_ID:?VPC_ID is required}"

echo "Region: $EKS_REGION"
echo "Cluster: ${EKS_CLUSTER_NAME:-unknown}"
echo "VPC: $VPC_ID"

read -r -a PUBLIC_SUBNET_LIST <<< "${PUBLIC_SUBNET_IDS:-}"
read -r -a PRIVATE_SUBNET_LIST <<< "${PRIVATE_SUBNET_IDS:-}"

echo "Deleting NAT Gateway..."
if [[ -n "${NAT_GATEWAY_ID:-}" ]]; then
  aws_cli ec2 delete-nat-gateway \
    --nat-gateway-id "$NAT_GATEWAY_ID" || true

  aws_cli ec2 wait nat-gateway-deleted \
    --nat-gateway-ids "$NAT_GATEWAY_ID" || true
fi

echo "Releasing NAT EIP..."
if [[ -n "${NAT_EIP_ALLOCATION_ID:-}" ]]; then
  aws_cli ec2 release-address \
    --allocation-id "$NAT_EIP_ALLOCATION_ID" || true
fi

echo "Disassociating route tables..."
for assoc in $(aws_cli ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].Associations[?Main==`false`].RouteTableAssociationId' \
  --output text); do

  aws_cli ec2 disassociate-route-table \
    --association-id "$assoc" || true
done

echo "Deleting non-main route tables..."
for rt in $(aws_cli ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
  --output text); do

  aws_cli ec2 delete-route-table \
    --route-table-id "$rt" || true
done

echo "Deleting subnets..."
for subnet in "${PUBLIC_SUBNET_LIST[@]}" "${PRIVATE_SUBNET_LIST[@]}"; do
  [[ -n "$subnet" ]] || continue
  aws_cli ec2 delete-subnet \
    --subnet-id "$subnet" || true
done

echo "Deleting Internet Gateway..."
if [[ -n "${INTERNET_GATEWAY_ID:-}" ]]; then
  aws_cli ec2 detach-internet-gateway \
    --internet-gateway-id "$INTERNET_GATEWAY_ID" \
    --vpc-id "$VPC_ID" || true

  aws_cli ec2 delete-internet-gateway \
    --internet-gateway-id "$INTERNET_GATEWAY_ID" || true
fi

echo "Deleting VPC..."
aws_cli ec2 delete-vpc \
  --vpc-id "$VPC_ID" || true
