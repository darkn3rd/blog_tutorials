#!/usr/bin/env bash

################
# Instances 
############################
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$USER-webserver" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text
)

aws ec2 terminate-instances --instance-ids $INSTANCE_ID

################
# Database 
############################
aws rds delete-db-instance --db-instance-identifier "$USER-db" --skip-final-snapshot
aws rds delete-db-subnet-group --db-subnet-group-name "$USER-dbsg"

################
# Security Groups 
############################
WEB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=$USER-webserver" \
  --query "SecurityGroups[0].GroupId" \
  --output text
)

DB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=$USER-database" \
  --query "SecurityGroups[0].GroupId" \
  --output text
)

aws ec2 delete-security-group --group-id $DB_SG_ID
aws ec2 delete-security-group --group-id $WEB_SG_ID

################
# Subnets
############################
SUBNET_ID=$(aws ec2 describe-subnets \
  --filter "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$USER-public1" \
  --query 'Subnets[0].SubnetId' \
  --output text
)

SUBNETS=$(aws ec2 describe-subnets \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].SubnetId' \
  --output text
)

for SUBNET_ID in $SUBNETS; do
  aws ec2 delete-subnet --subnet-id $SUBNET_ID
done

################
# IGW
############################
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

################
# Route Tables
############################
RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[0].RouteTableId" \
  --output text
)

RTBASSOC_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[0].Associations[1].RouteTableAssociationId" \
  --output text
)

aws ec2  disassociate-route-table --association-id $RTBASSOC_ID
# An error occurred (InvalidParameterValue) when calling the DisassociateRouteTable 
# operation: cannot disassociate the main route table association rtbassoc-0891578c68ba31787
aws ec2 delete-route-table --route-table-id $RT_ID
# An error occurred (DependencyViolation) when calling the DeleteRouteTable operation: 
# The routeTable 'rtb-0adde0d1f60ce8c4d' has dependencies and cannot be deleted.

################
# VPC
############################
aws ec2 delete-vpc --vpc-id $VPC_ID