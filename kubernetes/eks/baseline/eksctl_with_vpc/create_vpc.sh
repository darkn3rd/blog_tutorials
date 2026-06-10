#!/usr/bin/env bash
set -euo pipefail

# Required environment variables:
#   AWS_PROFILE
#   EKS_CLUSTER_NAME
#   EKS_REGION
#   EKS_VERSION
#
# Optional:
#   KUBECONFIG
#
# Usage:
#   ./create_eks_vpc
#
# Then:
#   eksctl create cluster -f cluster.yaml

#######################################
# Helpers
#######################################
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

#######################################
# Validate env
#######################################
require_env AWS_PROFILE
require_env EKS_CLUSTER_NAME
require_env EKS_REGION
require_env EKS_VERSION

if [[ "$EKS_REGION" != "us-east-2" ]]; then
  cat >&2 <<EOF
ERROR: this script currently hardcodes the subnet/AZ layout from your pasted eksctl templates,
which are for us-east-2.

Set:
  export EKS_REGION="us-east-2"

Or modify the AZ/CIDR block section in this script for another region.
EOF
  exit 1
fi

#######################################
# Layout from provided eksctl template
#######################################
VPC_CIDR="192.168.0.0/16"

AZ_A="us-east-2a"
AZ_B="us-east-2b"
AZ_C="us-east-2c"

PUB_C_CIDR="192.168.0.0/19"
PUB_A_CIDR="192.168.32.0/19"
PUB_B_CIDR="192.168.64.0/19"

PRIV_C_CIDR="192.168.96.0/19"
PRIV_A_CIDR="192.168.128.0/19"
PRIV_B_CIDR="192.168.160.0/19"

# Naming close to eksctl-generated names
STACK_PREFIX="${EKS_CLUSTER_NAME}"

#######################################
# Safety checks
#######################################
log "Checking AWS caller identity"
aws_cli sts get-caller-identity >/dev/null

EXISTING_VPC=$(aws_cli ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${STACK_PREFIX}/VPC" \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || true)

if [[ -n "${EXISTING_VPC:-}" && "$EXISTING_VPC" != "None" ]]; then
  cat >&2 <<EOF
ERROR: Found an existing VPC tagged Name=${STACK_PREFIX}/VPC: ${EXISTING_VPC}

This script is intentionally conservative and will not continue.
Delete or rename existing resources first, or change EKS_CLUSTER_NAME.
EOF
  exit 1
fi

#######################################
# Create VPC
#######################################
log "Creating VPC"
VPC_ID=$(aws_cli ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications "$(tag_spec vpc "{Key=Name,Value=${STACK_PREFIX}/VPC}")" \
  --query 'Vpc.VpcId' \
  --output text)

aws_cli ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
aws_cli ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames

log "Created VPC: $VPC_ID"

#######################################
# Create Internet Gateway
#######################################
log "Creating Internet Gateway"
IGW_ID=$(aws_cli ec2 create-internet-gateway \
  --tag-specifications "$(tag_spec internet-gateway "{Key=Name,Value=${STACK_PREFIX}/InternetGateway}")" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws_cli ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

log "Created and attached IGW: $IGW_ID"

#######################################
# Create public subnets
#######################################
log "Creating public subnets"

PUB_C_ID=$(aws_cli ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --availability-zone "$AZ_C" \
  --cidr-block "$PUB_C_CIDR" \
  --tag-specifications "$(tag_spec subnet "{Key=Name,Value=${STACK_PREFIX}/SubnetPublicUSEAST2C},{Key=kubernetes.io/role/elb,Value=1},{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}")" \
  --query 'Subnet.SubnetId' \
  --output text)

PUB_A_ID=$(aws_cli ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --availability-zone "$AZ_A" \
  --cidr-block "$PUB_A_CIDR" \
  --tag-specifications "$(tag_spec subnet "{Key=Name,Value=${STACK_PREFIX}/SubnetPublicUSEAST2A},{Key=kubernetes.io/role/elb,Value=1},{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}")" \
  --query 'Subnet.SubnetId' \
  --output text)

PUB_B_ID=$(aws_cli ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --availability-zone "$AZ_B" \
  --cidr-block "$PUB_B_CIDR" \
  --tag-specifications "$(tag_spec subnet "{Key=Name,Value=${STACK_PREFIX}/SubnetPublicUSEAST2B},{Key=kubernetes.io/role/elb,Value=1},{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}")" \
  --query 'Subnet.SubnetId' \
  --output text)

aws_cli ec2 modify-subnet-attribute --subnet-id "$PUB_C_ID" --map-public-ip-on-launch
aws_cli ec2 modify-subnet-attribute --subnet-id "$PUB_A_ID" --map-public-ip-on-launch
aws_cli ec2 modify-subnet-attribute --subnet-id "$PUB_B_ID" --map-public-ip-on-launch

log "Public subnets:"
echo "  $AZ_C => $PUB_C_ID ($PUB_C_CIDR)"
echo "  $AZ_A => $PUB_A_ID ($PUB_A_CIDR)"
echo "  $AZ_B => $PUB_B_ID ($PUB_B_CIDR)"

#######################################
# Create private subnets
#######################################
log "Creating private subnets"

PRIV_C_ID=$(aws_cli ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --availability-zone "$AZ_C" \
  --cidr-block "$PRIV_C_CIDR" \
  --tag-specifications "$(tag_spec subnet "{Key=Name,Value=${STACK_PREFIX}/SubnetPrivateUSEAST2C},{Key=kubernetes.io/role/internal-elb,Value=1},{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}")" \
  --query 'Subnet.SubnetId' \
  --output text)

PRIV_A_ID=$(aws_cli ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --availability-zone "$AZ_A" \
  --cidr-block "$PRIV_A_CIDR" \
  --tag-specifications "$(tag_spec subnet "{Key=Name,Value=${STACK_PREFIX}/SubnetPrivateUSEAST2A},{Key=kubernetes.io/role/internal-elb,Value=1},{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}")" \
  --query 'Subnet.SubnetId' \
  --output text)

PRIV_B_ID=$(aws_cli ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --availability-zone "$AZ_B" \
  --cidr-block "$PRIV_B_CIDR" \
  --tag-specifications "$(tag_spec subnet "{Key=Name,Value=${STACK_PREFIX}/SubnetPrivateUSEAST2B},{Key=kubernetes.io/role/internal-elb,Value=1},{Key=kubernetes.io/cluster/${EKS_CLUSTER_NAME},Value=shared}")" \
  --query 'Subnet.SubnetId' \
  --output text)

log "Private subnets:"
echo "  $AZ_C => $PRIV_C_ID ($PRIV_C_CIDR)"
echo "  $AZ_A => $PRIV_A_ID ($PRIV_A_CIDR)"
echo "  $AZ_B => $PRIV_B_ID ($PRIV_B_CIDR)"

#######################################
# Public route table
#######################################
log "Creating public route table"

PUB_RT_ID=$(aws_cli ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec route-table "{Key=Name,Value=${STACK_PREFIX}/PublicRouteTable}")" \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws_cli ec2 create-route \
  --route-table-id "$PUB_RT_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" >/dev/null

aws_cli ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB_C_ID" >/dev/null
aws_cli ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB_A_ID" >/dev/null
aws_cli ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB_B_ID" >/dev/null

log "Public route table: $PUB_RT_ID"

#######################################
# NAT + EIP
#######################################
log "Allocating EIP for NAT Gateway"
EIP_ALLOC_ID=$(aws_cli ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' \
  --output text)

# Tag the EIP separately because allocate-address doesn't support tag-specifications consistently across older CLI/service combinations
aws_cli ec2 create-tags \
  --resources "$EIP_ALLOC_ID" \
  --tags "Key=Name,Value=${STACK_PREFIX}/NATIP" >/dev/null || true

log "Creating NAT Gateway in public subnet $PUB_C_ID ($AZ_C)"
NAT_GW_ID=$(aws_cli ec2 create-nat-gateway \
  --subnet-id "$PUB_C_ID" \
  --allocation-id "$EIP_ALLOC_ID" \
  --tag-specifications "$(tag_spec natgateway "{Key=Name,Value=${STACK_PREFIX}/NATGateway}")" \
  --query 'NatGateway.NatGatewayId' \
  --output text)

log "Waiting for NAT Gateway to become available: $NAT_GW_ID"
aws_cli ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID"

#######################################
# Private route tables
#######################################
log "Creating private route tables"

PRIV_RT_A=$(aws_cli ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec route-table "{Key=Name,Value=${STACK_PREFIX}/PrivateRouteTableUSEAST2A}")" \
  --query 'RouteTable.RouteTableId' \
  --output text)

PRIV_RT_B=$(aws_cli ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec route-table "{Key=Name,Value=${STACK_PREFIX}/PrivateRouteTableUSEAST2B}")" \
  --query 'RouteTable.RouteTableId' \
  --output text)

PRIV_RT_C=$(aws_cli ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec route-table "{Key=Name,Value=${STACK_PREFIX}/PrivateRouteTableUSEAST2C}")" \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws_cli ec2 create-route --route-table-id "$PRIV_RT_A" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID" >/dev/null
aws_cli ec2 create-route --route-table-id "$PRIV_RT_B" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID" >/dev/null
aws_cli ec2 create-route --route-table-id "$PRIV_RT_C" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID" >/dev/null

aws_cli ec2 associate-route-table --route-table-id "$PRIV_RT_A" --subnet-id "$PRIV_A_ID" >/dev/null
aws_cli ec2 associate-route-table --route-table-id "$PRIV_RT_B" --subnet-id "$PRIV_B_ID" >/dev/null
aws_cli ec2 associate-route-table --route-table-id "$PRIV_RT_C" --subnet-id "$PRIV_C_ID" >/dev/null

log "Private route tables:"
echo "  $AZ_A => $PRIV_RT_A"
echo "  $AZ_B => $PRIV_RT_B"
echo "  $AZ_C => $PRIV_RT_C"

#######################################
# Write cluster.yaml
#######################################
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
      ${AZ_A}:
        id: ${PUB_A_ID}
      ${AZ_B}:
        id: ${PUB_B_ID}
      ${AZ_C}:
        id: ${PUB_C_ID}
    private:
      ${AZ_A}:
        id: ${PRIV_A_ID}
      ${AZ_B}:
        id: ${PRIV_B_ID}
      ${AZ_C}:
        id: ${PRIV_C_ID}

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
      - ${PRIV_A_ID}
      - ${PRIV_B_ID}
      - ${PRIV_C_ID}
      
addonsConfig:
  autoApplyPodIdentityAssociations: true

addons:
  - name: vpc-cni
    useDefaultPodIdentityAssociations: true
  - name: aws-ebs-csi-driver
    useDefaultPodIdentityAssociations: true

EOF

#######################################
# Write summary file
#######################################
cat > vpc-outputs.env <<EOF
export AWS_PROFILE="${AWS_PROFILE}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME}"
export EKS_REGION="${EKS_REGION}"
export EKS_VERSION="${EKS_VERSION}"
export VPC_ID="${VPC_ID}"
export INTERNET_GATEWAY_ID="${IGW_ID}"
export NAT_GATEWAY_ID="${NAT_GW_ID}"
export NAT_EIP_ALLOCATION_ID="${EIP_ALLOC_ID}"
export PUBLIC_SUBNET_A_ID="${PUB_A_ID}"
export PUBLIC_SUBNET_B_ID="${PUB_B_ID}"
export PUBLIC_SUBNET_C_ID="${PUB_C_ID}"
export PRIVATE_SUBNET_A_ID="${PRIV_A_ID}"
export PRIVATE_SUBNET_B_ID="${PRIV_B_ID}"
export PRIVATE_SUBNET_C_ID="${PRIV_C_ID}"
export PUBLIC_ROUTE_TABLE_ID="${PUB_RT_ID}"
export PRIVATE_ROUTE_TABLE_A_ID="${PRIV_RT_A}"
export PRIVATE_ROUTE_TABLE_B_ID="${PRIV_RT_B}"
export PRIVATE_ROUTE_TABLE_C_ID="${PRIV_RT_C}"
EOF

#######################################
# Final output
#######################################
log "Done"

cat <<EOF

Created network resources for cluster: ${EKS_CLUSTER_NAME}

VPC:
  ${VPC_ID}

Public subnets:
  ${AZ_A}: ${PUB_A_ID} (${PUB_A_CIDR})
  ${AZ_B}: ${PUB_B_ID} (${PUB_B_CIDR})
  ${AZ_C}: ${PUB_C_ID} (${PUB_C_CIDR})

Private subnets:
  ${AZ_A}: ${PRIV_A_ID} (${PRIV_A_CIDR})
  ${AZ_B}: ${PRIV_B_ID} (${PRIV_B_CIDR})
  ${AZ_C}: ${PRIV_C_ID} (${PRIV_C_CIDR})

Files written:
  ./cluster.yaml
  ./vpc-outputs.env

Next step:
  eksctl create cluster -f cluster.yaml

Optional:
  export KUBECONFIG="\$HOME/.kube/${EKS_REGION}.${EKS_CLUSTER_NAME}.yaml"
  source ./vpc-outputs.env
EOF
