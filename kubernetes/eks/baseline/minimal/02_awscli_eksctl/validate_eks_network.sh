#!/usr/bin/env bash
set -euo pipefail

source ../shared_lib/shell_lib/common.sh
source ../shared_lib/shell_lib/aws.sh

validate_files() {
  [[ -f ./vpc-outputs.env ]] || die "missing ./vpc-outputs.env"
  [[ -f ./cluster.yaml ]] || die "missing ./cluster.yaml"
}

validate_cluster_yaml_matches_env() {
  local yaml_vpc_id
  yaml_vpc_id="$(yq -r '.vpc.id' cluster.yaml)"

  [[ "$yaml_vpc_id" == "$VPC_ID" ]] || die "cluster.yaml VPC does not match vpc-outputs.env"

  for az in us-east-2a us-east-2b us-east-2c; do
    local suffix="${az^^}"
    suffix="${suffix//-/}"

    local public_var="PUBLIC_SUBNET_${suffix}_ID"
    local private_var="PRIVATE_SUBNET_${suffix}_ID"

    local yaml_public
    local yaml_private

    yaml_public="$(yq -r ".vpc.subnets.public.\"$az\".id" cluster.yaml)"
    yaml_private="$(yq -r ".vpc.subnets.private.\"$az\".id" cluster.yaml)"

    [[ "$yaml_public" == "${!public_var}" ]] || die "public subnet mismatch for $az"
    [[ "$yaml_private" == "${!private_var}" ]] || die "private subnet mismatch for $az"
  done
}

validate_aws_resources_exist() {
  aws_cli ec2 describe-vpcs --vpc-ids "$VPC_ID" >/dev/null
  aws_cli ec2 describe-internet-gateways --internet-gateway-ids "$INTERNET_GATEWAY_ID" >/dev/null
  aws_cli ec2 describe-nat-gateways --nat-gateway-ids "$NAT_GATEWAY_ID" >/dev/null
  aws_cli ec2 describe-addresses --allocation-ids "$NAT_EIP_ALLOCATION_ID" >/dev/null

  for var in ${!PUBLIC_SUBNET_*_ID} ${!PRIVATE_SUBNET_*_ID}; do
    aws_cli ec2 describe-subnets --subnet-ids "${!var}" >/dev/null
  done

  for var in ${!PUBLIC_ROUTE_TABLE_*_ID} ${!PRIVATE_ROUTE_TABLE_*_ID}; do
    aws_cli ec2 describe-route-tables --route-table-ids "${!var}" >/dev/null
  done
}

main() {
  validate_files
  source ./vpc-outputs.env

  require_envs AWS_PROFILE EKS_REGION VPC_ID
  require_commands aws yq

  validate_cluster_yaml_matches_env
  validate_aws_resources_exist

  log "Network validation passed"
}

main "$@"