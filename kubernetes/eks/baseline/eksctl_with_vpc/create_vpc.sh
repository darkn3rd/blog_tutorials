#!/usr/bin/env bash
set -euo pipefail

main() {
  validate_env
  set_layout
  safety_checks

  create_vpc
  create_igw
  create_subnet_pub
  create_subnet_priv
  create_rt_pub
  create_nat
  create_rt_priv

  write_cluster_yaml
  write_outputs_env
  print_summary
}

log() {
  printf '\n[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

require_env() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: environment variable '$var' is required" >&2
    exit 1
  fi
}

aws_cli() {
  aws --profile "$AWS_PROFILE" --region "$EKS_REGION" "$@"
}

tag_spec() {
  local resource_type="$1"
  local tags="$2"
  printf "ResourceType=%s,Tags=[%s]" "$resource_type" "$tags"
}

az_suffix() {
  local az="$1"
  echo "${az^^}" | tr -d '-'
}

aws_text_exists() {
  local value="${1:-}"
  [[ -n "$value" && "$value" != "None" ]]
}

validate_env() {
  require_env AWS_PROFILE
  require_env EKS_CLUSTER_NAME
  require_env EKS_REGION
  require_env EKS_VERSION

  if [[ "$EKS_REGION" != "us-east-2" ]]; then
    cat >&2 <<EOF
ERROR: this script currently hardcodes the subnet/AZ layout for us-east-2.

Set:
  export EKS_REGION="us-east-2"
EOF
    exit 1
  fi
}

set_layout() {
  VPC_CIDR="192.168.0.0/16"
  STACK_PREFIX="${EKS_CLUSTER_NAME}"

  AZS=(
    us-east-2a
    us-east-2b
    us-east-2c
  )

  declare -gA PUB_CIDRS=(
    [us-east-2a]="192.168.32.0/19"
    [us-east-2b]="192.168.64.0/19"
    [us-east-2c]="192.168.0.0/19"
  )

  declare -gA PRIV_CIDRS=(
    [us-east-2a]="192.168.128.0/19"
    [us-east-2b]="192.168.160.0/19"
    [us-east-2c]="192.168.96.0/19"
  )

  declare -gA PUB_SUBNETS
  declare -gA PRIV_SUBNETS
  declare -gA PUB_RTS
  declare -gA PRIV_RTS
}

safety_checks() {
  log "Checking AWS caller identity"
  aws_cli sts get-caller-identity >/dev/null
}

find_igw_by_name() {
  aws_cli ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=$1" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || true
}

find_nat_by_name() {
  aws_cli ec2 describe-nat-gateways \
    --filter \
      "Name=vpc-id,Values=${VPC_ID}" \
      "Name=tag:Name,Values=$1" \
      "Name=state,Values=pending,available" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || true
}

find_eip_by_name() {
  aws_cli ec2 describe-addresses \
    --filters "Name=tag:Name,Values=$1" \
    --query 'Addresses[0].AllocationId' \
    --output text 2>/dev/null || true
}

find_subnet_by_name() {
  aws_cli ec2 describe-subnets \
    --filters \
      "Name=vpc-id,Values=${VPC_ID}" \
      "Name=tag:Name,Values=$1" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true
}

find_route_table_by_name() {
  aws_cli ec2 describe-route-tables \
    --filters \
      "Name=vpc-id,Values=${VPC_ID}" \
      "Name=tag:Name,Values=$1" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || true
}

ensure_route() {
  local route_table_id="$1"
  local destination="$2"
  local target_type="$3"
  local target_id="$4"

  local existing
  existing=$(aws_cli ec2 describe-route-tables \
    --route-table-ids "$route_table_id" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='${destination}'] | [0].DestinationCidrBlock" \
    --output text 2>/dev/null || true)

  if aws_text_exists "$existing"; then
    log "Route already exists on $route_table_id: $destination"
    return
  fi

  aws_cli ec2 create-route \
    --route-table-id "$route_table_id" \
    --destination-cidr-block "$destination" \
    "$target_type" "$target_id" >/dev/null
}

ensure_route_table_association() {
  local route_table_id="$1"
  local subnet_id="$2"

  local existing_rt
  existing_rt=$(aws_cli ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=${subnet_id}" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || true)

  if [[ "$existing_rt" == "$route_table_id" ]]; then
    log "Subnet already associated: $subnet_id -> $route_table_id"
    return
  fi

  if aws_text_exists "$existing_rt"; then
    local assoc_id
    assoc_id=$(aws_cli ec2 describe-route-tables \
      --filters "Name=association.subnet-id,Values=${subnet_id}" \
      --query 'RouteTables[0].Associations[0].RouteTableAssociationId' \
      --output text)

    aws_cli ec2 replace-route-table-association \
      --association-id "$assoc_id" \
      --route-table-id "$route_table_id" >/dev/null

    log "Replaced route table association: $subnet_id -> $route_table_id"
    return
  fi

  aws_cli ec2 associate-route-table \
    --route-table-id "$route_table_id" \
    --subnet-id "$subnet_id" >/dev/null

  log "Associated subnet: $subnet_id -> $route_table_id"
}

create_vpc() {
  local tag_specification
  
  if [[ -n "${VPC_ID:-}" ]]; then
    log "VPC_ID is set; verifying VPC exists: $VPC_ID"
    aws_cli ec2 describe-vpcs --vpc-ids "$VPC_ID" >/dev/null
    log "Using existing VPC: $VPC_ID"
    return
  fi

  VPC_ID=$(aws_cli ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${STACK_PREFIX}/VPC" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || true)

  if aws_text_exists "$VPC_ID"; then
    log "Using existing VPC by tag: $VPC_ID"
    return
  fi

  log "Creating VPC"

  tag_specification=$(tag_spec \
    vpc \
    "{Key=Name,Value=${STACK_PREFIX}/VPC}")

  VPC_ID=$(aws_cli ec2 create-vpc \
    --cidr-block "$VPC_CIDR" \
    --tag-specifications "$tag_specification" \
    --query 'Vpc.VpcId' \
    --output text)

  aws_cli ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
  aws_cli ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames

  log "Created VPC: $VPC_ID"
}

create_igw() {
  local name="${STACK_PREFIX}/InternetGateway"
  local tag_specification

  if [[ -n "${IGW_ID:-}" ]]; then
    aws_cli ec2 describe-internet-gateways \
      --internet-gateway-ids "$IGW_ID" >/dev/null
  else
    IGW_ID=$(find_igw_by_name "$name")
  fi

  if aws_text_exists "$IGW_ID"; then
    log "Using existing Internet Gateway: $IGW_ID"
  else
    log "Creating Internet Gateway"

    tag_specification=$(tag_spec \
      internet-gateway \
      "{Key=Name,Value=${name}}")

    IGW_ID=$(aws_cli ec2 create-internet-gateway \
      --tag-specifications "$tag_specification" \
      --query 'InternetGateway.InternetGatewayId' \
      --output text)

    log "Created Internet Gateway: $IGW_ID"
  fi

  local attached_vpc
  attached_vpc=$(aws_cli ec2 describe-internet-gateways \
    --internet-gateway-ids "$IGW_ID" \
    --query 'InternetGateways[0].Attachments[0].VpcId' \
    --output text 2>/dev/null || true)

  if [[ "$attached_vpc" == "$VPC_ID" ]]; then
    log "Internet Gateway already attached to VPC: $VPC_ID"
  else
    aws_cli ec2 attach-internet-gateway \
      --internet-gateway-id "$IGW_ID" \
      --vpc-id "$VPC_ID"

    log "Attached Internet Gateway: $IGW_ID -> $VPC_ID"
  fi
}

create_subnet_pub() {
  log "Creating/reusing public subnets"

  local az suffix name existing tag_specification
  local -a tags

  for az in "${AZS[@]}"; do
    suffix=$(az_suffix "$az")
    name="${STACK_PREFIX}/SubnetPublic${suffix}"

    existing=$(find_subnet_by_name "$name")

    if aws_text_exists "$existing"; then
      PUB_SUBNETS[$az]="$existing"
      log "Using existing public subnet for $az: ${PUB_SUBNETS[$az]}"
    else
      tags=(
        "{Key=Name,Value=${name}}"
        "{Key=kubernetes.io/role/elb,Value=1}"
        "{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}"
      )

      tag_specification=$(tag_spec \
        subnet \
        "$(IFS=,; echo "${tags[*]}")")

      PUB_SUBNETS[$az]=$(aws_cli ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --availability-zone "$az" \
        --cidr-block "${PUB_CIDRS[$az]}" \
        --tag-specifications "$tag_specification" \
        --query 'Subnet.SubnetId' \
        --output text)

      log "Created public subnet for $az: ${PUB_SUBNETS[$az]}"
    fi

    aws_cli ec2 modify-subnet-attribute \
      --subnet-id "${PUB_SUBNETS[$az]}" \
      --map-public-ip-on-launch
  done
}

create_subnet_priv() {
  log "Creating/reusing private subnets"

  local az suffix name existing tag_specification
  local -a tags

  for az in "${AZS[@]}"; do
    suffix=$(az_suffix "$az")
    name="${STACK_PREFIX}/SubnetPrivate${suffix}"

    existing=$(find_subnet_by_name "$name")

    if aws_text_exists "$existing"; then
      PRIV_SUBNETS[$az]="$existing"
      log "Using existing private subnet for $az: ${PRIV_SUBNETS[$az]}"
      continue
    fi

    tags=(
      "{Key=Name,Value=${name}}"
      "{Key=kubernetes.io/role/internal-elb,Value=1}"
      "{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}"
    ) 

    tag_specification=$(tag_spec \
      subnet \
      "$(IFS=,; echo "${tags[*]}")")

    PRIV_SUBNETS[$az]=$(aws_cli ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --availability-zone "$az" \
      --cidr-block "${PRIV_CIDRS[$az]}" \
      --tag-specifications "$tag_specification" \
      --query 'Subnet.SubnetId' \
      --output text)

    log "Created private subnet for $az: ${PRIV_SUBNETS[$az]}"
  done
}

create_rt_pub() {
  local name="${STACK_PREFIX}/PublicRouteTable"

  log "Creating/reusing public route table"

  PUB_RT_ID=$(find_route_table_by_name "$name")

  if aws_text_exists "$PUB_RT_ID"; then
    log "Using existing public route table: $PUB_RT_ID"
  else
    PUB_RT_ID=$(aws_cli ec2 create-route-table \
      --vpc-id "$VPC_ID" \
      --tag-specifications "$(tag_spec route-table "{Key=Name,Value=${name}}")" \
      --query 'RouteTable.RouteTableId' \
      --output text)

    log "Created public route table: $PUB_RT_ID"
  fi

  ensure_route "$PUB_RT_ID" "0.0.0.0/0" "--gateway-id" "$IGW_ID"

  local az
  for az in "${AZS[@]}"; do
    ensure_route_table_association "$PUB_RT_ID" "${PUB_SUBNETS[$az]}"
    PUB_RTS[$az]="$PUB_RT_ID"
  done
}

create_nat() {
  local eip_name="${STACK_PREFIX}/NATIP"
  local nat_name="${STACK_PREFIX}/NATGateway"
  local nat_az="${AZS[0]}"

  NAT_GW_ID=$(find_nat_by_name "$nat_name")

  if aws_text_exists "$NAT_GW_ID"; then
    log "Using existing NAT Gateway: $NAT_GW_ID"

    EIP_ALLOC_ID=$(aws_cli ec2 describe-nat-gateways \
      --nat-gateway-ids "$NAT_GW_ID" \
      --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' \
      --output text)

    return
  fi

  EIP_ALLOC_ID=$(find_eip_by_name "$eip_name")

  if aws_text_exists "$EIP_ALLOC_ID"; then
    log "Using existing EIP for NAT Gateway: $EIP_ALLOC_ID"
  else
    log "Allocating EIP for NAT Gateway"

    EIP_ALLOC_ID=$(aws_cli ec2 allocate-address \
      --domain vpc \
      --query 'AllocationId' \
      --output text)

    aws_cli ec2 create-tags \
      --resources "$EIP_ALLOC_ID" \
      --tags "Key=Name,Value=${eip_name}" >/dev/null
  fi

  log "Creating NAT Gateway in public subnet ${PUB_SUBNETS[$nat_az]} ($nat_az)"

  NAT_GW_ID=$(aws_cli ec2 create-nat-gateway \
    --subnet-id "${PUB_SUBNETS[$nat_az]}" \
    --allocation-id "$EIP_ALLOC_ID" \
    --tag-specifications "$(tag_spec natgateway "{Key=Name,Value=${nat_name}}")" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

  log "Waiting for NAT Gateway: $NAT_GW_ID"
  aws_cli ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID"
}

create_rt_priv() {
  log "Creating/reusing private route tables"

  local az suffix name existing

  for az in "${AZS[@]}"; do
    suffix=$(az_suffix "$az")
    name="${STACK_PREFIX}/PrivateRouteTable${suffix}"

    existing=$(find_route_table_by_name "$name")

    if aws_text_exists "$existing"; then
      PRIV_RTS[$az]="$existing"
      log "Using existing private route table for $az: ${PRIV_RTS[$az]}"
    else
      PRIV_RTS[$az]=$(aws_cli ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --tag-specifications "$(tag_spec route-table "{Key=Name,Value=${name}}")" \
        --query 'RouteTable.RouteTableId' \
        --output text)

      log "Created private route table for $az: ${PRIV_RTS[$az]}"
    fi

    ensure_route "${PRIV_RTS[$az]}" "0.0.0.0/0" "--nat-gateway-id" "$NAT_GW_ID"
    ensure_route_table_association "${PRIV_RTS[$az]}" "${PRIV_SUBNETS[$az]}"
  done
}

write_cluster_yaml() {
  log "Writing cluster.yaml"

  cat > cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${EKS_CLUSTER_NAME}
  region: ${EKS_REGION}
  version: "${EKS_VERSION}"

vpc:
  id: ${VPC_ID}
  subnets:
    public:
EOF

  local az
  for az in "${AZS[@]}"; do
    cat >> cluster.yaml <<EOF
      ${az}:
        id: ${PUB_SUBNETS[$az]}
EOF
  done

  cat >> cluster.yaml <<EOF
    private:
EOF

  for az in "${AZS[@]}"; do
    cat >> cluster.yaml <<EOF
      ${az}:
        id: ${PRIV_SUBNETS[$az]}
EOF
  done

  cat >> cluster.yaml <<EOF

managedNodeGroups:
  - name: ng-1
    amiFamily: AmazonLinux2023
    instanceType: m5.large
    desiredCapacity: 3
    minSize: 3
    maxSize: 3
    privateNetworking: true
    volumeSize: 80
    volumeType: gp3
    subnets:
EOF

  for az in "${AZS[@]}"; do
    cat >> cluster.yaml <<EOF
      - ${PRIV_SUBNETS[$az]}
EOF
  done

  cat >> cluster.yaml <<EOF

addonsConfig:
  autoApplyPodIdentityAssociations: true

addons:
  - name: vpc-cni
    useDefaultPodIdentityAssociations: true
  - name: aws-ebs-csi-driver
    useDefaultPodIdentityAssociations: true
EOF
}

write_outputs_env() {
  log "Writing vpc-outputs.env"

  cat > vpc-outputs.env <<EOF
export AWS_PROFILE="${AWS_PROFILE}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
export EKS_REGION="${EKS_REGION}"
export EKS_VERSION="${EKS_VERSION}"
export VPC_ID="${VPC_ID}"
export INTERNET_GATEWAY_ID="${IGW_ID}"
export NAT_GATEWAY_ID="${NAT_GW_ID}"
export NAT_EIP_ALLOCATION_ID="${EIP_ALLOC_ID}"
export PUBLIC_ROUTE_TABLE_ID="${PUB_RT_ID}"
EOF

  local az suffix
  for az in "${AZS[@]}"; do
    suffix=$(az_suffix "$az")

    cat >> vpc-outputs.env <<EOF
export PUBLIC_SUBNET_${suffix}_ID="${PUB_SUBNETS[$az]}"
export PRIVATE_SUBNET_${suffix}_ID="${PRIV_SUBNETS[$az]}"
export PUBLIC_ROUTE_TABLE_${suffix}_ID="${PUB_RTS[$az]}"
export PRIVATE_ROUTE_TABLE_${suffix}_ID="${PRIV_RTS[$az]}"
EOF
  done
}

print_summary() {
  log "Done"

  cat <<EOF

Created/reused network resources for cluster: ${EKS_CLUSTER_NAME}

VPC:
  ${VPC_ID}

Internet Gateway:
  ${IGW_ID}

NAT Gateway:
  ${NAT_GW_ID}

Public subnets:
EOF

  local az
  for az in "${AZS[@]}"; do
    cat <<EOF
  ${az}: ${PUB_SUBNETS[$az]} (${PUB_CIDRS[$az]})
EOF
  done

  cat <<EOF

Private subnets:
EOF

  for az in "${AZS[@]}"; do
    cat <<EOF
  ${az}: ${PRIV_SUBNETS[$az]} (${PRIV_CIDRS[$az]})
EOF
  done

  cat <<EOF

Route tables:
EOF

  for az in "${AZS[@]}"; do
    cat <<EOF
  ${az} public:  ${PUB_RTS[$az]}
  ${az} private: ${PRIV_RTS[$az]}
EOF
  done

  cat <<EOF

Files written:
  ./cluster.yaml
  ./vpc-outputs.env

Next step:
  eksctl create cluster -f cluster.yaml

Optional:
  export KUBECONFIG="\$HOME/.kube/${EKS_REGION}.${EKS_CLUSTER_NAME}.yaml"
  source ./vpc-outputs.env

EOF
}

main "$@"
