#!/usr/bin/env bash
set -euo pipefail

source ../shared_lib/shell_lib/common.sh
source ../shared_lib/shell_lib/aws.sh

validate_files() {
  [[ -f ./vpc-outputs.env ]] || die "missing ./vpc-outputs.env"
  [[ -f ./cluster.yaml ]] || die "missing ./cluster.yaml"
}

load_outputs() {
  source ./vpc-outputs.env

  require_envs AWS_PROFILE EKS_REGION VPC_ID AZS PUBLIC_SUBNET_IDS PRIVATE_SUBNET_IDS

  read -r -a AZ_LIST <<< "$AZS"
  read -r -a PUBLIC_SUBNET_LIST <<< "$PUBLIC_SUBNET_IDS"
  read -r -a PRIVATE_SUBNET_LIST <<< "$PRIVATE_SUBNET_IDS"
  read -r -a PUBLIC_RT_LIST <<< "${PUBLIC_ROUTE_TABLE_IDS:-}"
  read -r -a PRIVATE_RT_LIST <<< "${PRIVATE_ROUTE_TABLE_IDS:-}"
}

validate_lengths() {
  local az_count="${#AZ_LIST[@]}"

  [[ "${#PUBLIC_SUBNET_LIST[@]}" -eq "$az_count" ]] || die "PUBLIC_SUBNET_IDS count does not match AZS count"
  [[ "${#PRIVATE_SUBNET_LIST[@]}" -eq "$az_count" ]] || die "PRIVATE_SUBNET_IDS count does not match AZS count"

  if [[ -n "${PUBLIC_ROUTE_TABLE_IDS:-}" ]]; then
    [[ "${#PUBLIC_RT_LIST[@]}" -eq "$az_count" ]] || die "PUBLIC_ROUTE_TABLE_IDS count does not match AZS count"
  fi

  if [[ -n "${PRIVATE_ROUTE_TABLE_IDS:-}" ]]; then
    [[ "${#PRIVATE_RT_LIST[@]}" -eq "$az_count" ]] || die "PRIVATE_ROUTE_TABLE_IDS count does not match AZS count"
  fi
}

validate_cluster_yaml_matches_env() {
  local yaml_vpc_id
  yaml_vpc_id="$(yq -r '.vpc.id' cluster.yaml)"

  [[ "$yaml_vpc_id" == "$VPC_ID" ]] || die "cluster.yaml VPC does not match vpc-outputs.env"

  local i az yaml_public yaml_private
  for i in "${!AZ_LIST[@]}"; do
    az="${AZ_LIST[$i]}"

    yaml_public="$(yq -r ".vpc.subnets.public.\"$az\".id" cluster.yaml)"
    yaml_private="$(yq -r ".vpc.subnets.private.\"$az\".id" cluster.yaml)"

    [[ "$yaml_public" == "${PUBLIC_SUBNET_LIST[$i]}" ]] || die "public subnet mismatch for $az"
    [[ "$yaml_private" == "${PRIVATE_SUBNET_LIST[$i]}" ]] || die "private subnet mismatch for $az"
  done
}

validate_aws_resources_exist() {
  aws_cli ec2 describe-vpcs --vpc-ids "$VPC_ID" >/dev/null
  aws_cli ec2 describe-internet-gateways --internet-gateway-ids "$INTERNET_GATEWAY_ID" >/dev/null
  aws_cli ec2 describe-nat-gateways --nat-gateway-ids "$NAT_GATEWAY_ID" >/dev/null
  aws_cli ec2 describe-addresses --allocation-ids "$NAT_EIP_ALLOCATION_ID" >/dev/null

  local subnet_id route_table_id

  for subnet_id in "${PUBLIC_SUBNET_LIST[@]}" "${PRIVATE_SUBNET_LIST[@]}"; do
    aws_cli ec2 describe-subnets --subnet-ids "$subnet_id" >/dev/null
  done

  if [[ -n "${PUBLIC_ROUTE_TABLE_ID:-}" ]]; then
    aws_cli ec2 describe-route-tables --route-table-ids "$PUBLIC_ROUTE_TABLE_ID" >/dev/null
  fi

  for route_table_id in "${PUBLIC_RT_LIST[@]}" "${PRIVATE_RT_LIST[@]}"; do
    [[ -n "$route_table_id" ]] || continue
    aws_cli ec2 describe-route-tables --route-table-ids "$route_table_id" >/dev/null
  done
}

main() {
  validate_files
  require_commands aws yq
  
  load_outputs
  validate_lengths
  validate_cluster_yaml_matches_env
  validate_aws_resources_exist

  log "Network validation passed"
}

main "$@"