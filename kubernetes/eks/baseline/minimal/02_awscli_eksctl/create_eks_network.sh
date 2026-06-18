#!/usr/bin/env bash
set -euo pipefail

source ../shared_lib/shell_lib/common.sh
source ../shared_lib/shell_lib/aws.sh
source ../shared_lib/shell_lib/aws_net.sh

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

  confirm_overwrite
  write_cluster_yaml
  write_outputs_env
  print_summary
}

validate_env() {
  require_envs AWS_PROFILE EKS_CLUSTER_NAME EKS_REGION EKS_VERSION
  require_command aws
}

set_layout() {
  VPC_CIDR="192.168.0.0/16"
  STACK_PREFIX="${EKS_CLUSTER_NAME}"

  mapfile -t AZS < <(
    aws_cli ec2 describe-availability-zones \
      --filters "Name=state,Values=available" \
      --query 'AvailabilityZones[?ZoneType==`availability-zone`].ZoneName' \
      --output text | tr '\t' '\n' | sort | head -n 3
  )

  if [[ "${#AZS[@]}" -lt 2 ]]; then
    die "Expected at least 2 available AZs in region $EKS_REGION, found ${#AZS[@]}"
  fi

  declare -gA PUB_CIDRS
  declare -gA PRIV_CIDRS

  local i az
  for i in "${!AZS[@]}"; do
    az="${AZS[$i]}"

    # /19 subnets inside 192.168.0.0/16
    # Public:  192.168.0.0/19,  192.168.32.0/19,  192.168.64.0/19
    # Private: 192.168.96.0/19, 192.168.128.0/19, 192.168.160.0/19
    PUB_CIDRS[$az]="192.168.$((i * 32)).0/19"
    PRIV_CIDRS[$az]="192.168.$(((i + 3) * 32)).0/19"
  done

  declare -gA PUB_SUBNETS
  declare -gA PRIV_SUBNETS
  declare -gA PUB_RTS
  declare -gA PRIV_RTS
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

confirm_overwrite() {
  for file in cluster.yaml vpc-outputs.env; do
    if [[ -f "$file" ]]; then
      log "Overwriting existing file: $file"
    fi
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

iam:
  withOIDC: true

addonsConfig:
  autoApplyPodIdentityAssociations: true

addons:
  - name: vpc-cni
    useDefaultPodIdentityAssociations: true
  - name: aws-ebs-csi-driver
    useDefaultPodIdentityAssociations: true
  - name: eks-pod-identity-agent

EOF
}

write_outputs_env() {
  log "Writing vpc-outputs.env"

  {
    printf 'export AWS_PROFILE="%s"\n' "$AWS_PROFILE"
    printf 'export EKS_CLUSTER_NAME="%s"\n' "$EKS_CLUSTER_NAME"
    printf 'export EKS_REGION="%s"\n' "$EKS_REGION"
    printf 'export EKS_VERSION="%s"\n' "$EKS_VERSION"
    printf 'export VPC_ID="%s"\n' "$VPC_ID"
    printf 'export INTERNET_GATEWAY_ID="%s"\n' "$IGW_ID"
    printf 'export NAT_GATEWAY_ID="%s"\n' "$NAT_GW_ID"
    printf 'export NAT_EIP_ALLOCATION_ID="%s"\n' "$EIP_ALLOC_ID"
    printf 'export PUBLIC_ROUTE_TABLE_ID="%s"\n' "$PUB_RT_ID"

    printf 'export AZS="%s"\n' "${AZS[*]}"

    printf 'export PUBLIC_SUBNET_IDS="'
    for az in "${AZS[@]}"; do printf '%s ' "${PUB_SUBNETS[$az]}"; done
    printf '"\n'

    printf 'export PRIVATE_SUBNET_IDS="'
    for az in "${AZS[@]}"; do printf '%s ' "${PRIV_SUBNETS[$az]}"; done
    printf '"\n'

    printf 'export PUBLIC_ROUTE_TABLE_IDS="'
    for az in "${AZS[@]}"; do printf '%s ' "${PUB_RTS[$az]}"; done
    printf '"\n'

    printf 'export PRIVATE_ROUTE_TABLE_IDS="'
    for az in "${AZS[@]}"; do printf '%s ' "${PRIV_RTS[$az]}"; done
    printf '"\n'
  } > vpc-outputs.env
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
  export KUBECONFIG="\$HOME/.kube/aws/${EKS_REGION}.${EKS_CLUSTER_NAME}.yaml"
  source ./vpc-outputs.env

EOF
}

main "$@"
