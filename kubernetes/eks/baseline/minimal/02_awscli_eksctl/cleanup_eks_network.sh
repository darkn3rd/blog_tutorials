#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "./vpc-outputs.env" ]]; then
  echo "ERROR: vpc-outputs.env not found in current directory." >&2
  echo "Run this script from the directory where vpc-outputs.env was created." >&2
  exit 1
fi

source ./vpc-outputs.env

: "${EKS_REGION:?EKS_REGION is required}"
: "${VPC_ID:?VPC_ID is required}"

echo "Region: $EKS_REGION"
echo "Cluster: ${EKS_CLUSTER_NAME:-unknown}"
echo "VPC: $VPC_ID"

echo "Deleting NAT Gateway..."
if [[ -n "${NAT_GATEWAY_ID:-}" ]]; then
  aws ec2 delete-nat-gateway \
    --region "$EKS_REGION" \
    --nat-gateway-id "$NAT_GATEWAY_ID" || true

  aws ec2 wait nat-gateway-deleted \
    --region "$EKS_REGION" \
    --nat-gateway-ids "$NAT_GATEWAY_ID" || true
fi

echo "Releasing NAT EIP..."
if [[ -n "${NAT_EIP_ALLOCATION_ID:-}" ]]; then
  aws ec2 release-address \
    --region "$EKS_REGION" \
    --allocation-id "$NAT_EIP_ALLOCATION_ID" || true
fi

echo "Disassociating route tables..."
for assoc in $(aws ec2 describe-route-tables \
  --region "$EKS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].Associations[?Main==`false`].RouteTableAssociationId' \
  --output text); do

  aws ec2 disassociate-route-table \
    --region "$EKS_REGION" \
    --association-id "$assoc" || true
done

echo "Deleting non-main route tables..."
for rt in $(aws ec2 describe-route-tables \
  --region "$EKS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
  --output text); do

  aws ec2 delete-route-table \
    --region "$EKS_REGION" \
    --route-table-id "$rt" || true
done

echo "Deleting subnets..."
for subnet in \
  "${PUBLIC_SUBNET_USEAST2A_ID:-}" \
  "${PUBLIC_SUBNET_USEAST2B_ID:-}" \
  "${PUBLIC_SUBNET_USEAST2C_ID:-}" \
  "${PRIVATE_SUBNET_USEAST2A_ID:-}" \
  "${PRIVATE_SUBNET_USEAST2B_ID:-}" \
  "${PRIVATE_SUBNET_USEAST2C_ID:-}"
do
  [[ -n "$subnet" ]] || continue

  aws ec2 delete-subnet \
    --region "$EKS_REGION" \
    --subnet-id "$subnet" || true
done

echo "Deleting Internet Gateway..."
if [[ -n "${INTERNET_GATEWAY_ID:-}" ]]; then
  aws ec2 detach-internet-gateway \
    --region "$EKS_REGION" \
    --internet-gateway-id "$INTERNET_GATEWAY_ID" \
    --vpc-id "$VPC_ID" || true

  aws ec2 delete-internet-gateway \
    --region "$EKS_REGION" \
    --internet-gateway-id "$INTERNET_GATEWAY_ID" || true
fi

echo "Deleting VPC..."
aws ec2 delete-vpc \
  --region "$EKS_REGION" \
  --vpc-id "$VPC_ID" || true
