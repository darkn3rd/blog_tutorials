###############################################################################
# Resource Lookup Helpers
###############################################################################

# find_igw_by_name - find Internet Gateway ID by Name tag
find_igw_by_name() {
  local name="$1"
  local value

  value=$(aws_cli ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=$name" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || true)

  aws_text_or_empty "$value"
}

# find_nat_by_name - find NAT Gateway ID by Name tag
find_nat_by_name() {
  local name="$1"
  local value

  value=$(aws_cli ec2 describe-nat-gateways \
    --filter \
      "Name=vpc-id,Values=${VPC_ID}" \
      "Name=tag:Name,Values=$name" \
      "Name=state,Values=pending,available" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || true)

  aws_text_or_empty "$value"
}

# find_eip_by_name - find Elastic IP allocation ID by Name tag
find_eip_by_name() {
  local name="$1"
  local value

  value=$(aws_cli ec2 describe-addresses \
    --filters "Name=tag:Name,Values=$name" \
    --query 'Addresses[0].AllocationId' \
    --output text 2>/dev/null || true)

  aws_text_or_empty "$value"
}

# find_subnet_by_name - find subnet ID by Name tag within the current VPC
find_subnet_by_name() {
  local name="$1"
  local value

  value=$(aws_cli ec2 describe-subnets \
    --filters \
      "Name=vpc-id,Values=${VPC_ID}" \
      "Name=tag:Name,Values=$name" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true)

  aws_text_or_empty "$value"
}

# find_route_table_by_name - find route table ID by Name tag within the current VPC
find_route_table_by_name() {
  local name="$1"
  local value

  value=$(aws_cli ec2 describe-route-tables \
    --filters \
      "Name=vpc-id,Values=${VPC_ID}" \
      "Name=tag:Name,Values=$name" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || true)

  aws_text_or_empty "$value"
}

###############################################################################
# Route Management Helpers
###############################################################################

# ensure_route - create a route if the destination does not already exist
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
    
  existing=$(aws_text_or_empty "$existing")

  if aws_text_exists "$existing"; then
    log "Route already exists on $route_table_id: $destination"
    return
  fi

  aws_cli ec2 create-route \
    --route-table-id "$route_table_id" \
    --destination-cidr-block "$destination" \
    "$target_type" "$target_id" >/dev/null

  log "Created route on $route_table_id: $destination -> $target_type $target_id"
}

# ensure_route_table_association - associate a subnet with the desired route table
ensure_route_table_association() {
  local route_table_id="$1"
  local subnet_id="$2"

  local existing_rt
  existing_rt=$(aws_cli ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=${subnet_id}" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || true)
  existing_rt=$(aws_text_or_empty "$existing_rt")

  if [[ "$existing_rt" == "$route_table_id" ]]; then
    log "Subnet already associated: $subnet_id -> $route_table_id"
    return
  fi

  if aws_text_exists "$existing_rt"; then
    local assoc_id
    assoc_id=$(aws_cli ec2 describe-route-tables \
      --filters "Name=association.subnet-id,Values=${subnet_id}" \
      --query "RouteTables[0].Associations[?SubnetId=='${subnet_id}'] | [0].RouteTableAssociationId" \
      --output text 2>/dev/null || true)
    assoc_id=$(aws_text_or_empty "$assoc_id")

    aws_text_exists "$assoc_id" || die "Could not find route table association for subnet $subnet_id"

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
