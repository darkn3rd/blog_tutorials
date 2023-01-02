#!/usr/bin/env bash

JSON_DATA=$(aws ec2 create-vpc \
  --cidr-block "10.0.0.0/16" \
  --tag-specifications \
    "ResourceType=vpc,Tags=[{Key=Name,Value=$USER-vpc},{Key=Sitetring,Value=$USER-web-site}]"
)

VPC_ID=$(jq .Vpc.VpcId -r <<< $JSON_DATA)
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$USER-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text
)

AZ_ZONES=($(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[*].ZoneName' \
  --output text))

################
# Public Subnets
############################
JSON_DATA=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --availability-zone ${AZ_ZONES[0]} \
  --cidr-block "10.0.1.0/24" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$USER-public1},{Key=Sitetring,Value=$USER-web-site}]"
)

SUBNET_ID=$(jq -r .Subnet.SubnetId -r <<< $JSON_DATA)
aws ec2 modify-subnet-attribute \
  --map-public-ip-on-launch \
  --subnet-id $SUBNET_ID

JSON_DATA=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --availability-zone ${AZ_ZONES[1]} \
  --cidr-block "10.0.2.0/24"
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$USER-public2},{Key=Sitetring,Value=$USER-web-site}]"
)

SUBNET_ID=$(jq -r .Subnet.SubnetId -r <<< $JSON_DATA)
aws ec2 modify-subnet-attribute \
  --map-public-ip-on-launch \
  --subnet-id $SUBNET_ID

# get subnet id


################
# Private Subnets
############################
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --availability-zone ${AZ_ZONES[0]} \
  --cidr-block "10.0.3.0/24"
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$USER-private1},{Key=Sitetring,Value=$USER-web-site}]"

aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --availability-zone ${AZ_ZONES[1]} \
  --cidr-block "10.0.4.0/24"
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$USER-private2},{Key=Sitetring,Value=$USER-web-site}]"


JSON_DATA=$(aws ec2 create-internet-gateway \
  --tag-specifications" ResourceType=internet-gateway,Tags=[{Key=Name,Value=$USER-igw},{Key=Sitetring,Value=$USER-web-site}]"
)

################
# Internet Gateway 
############################
aws ec2 attach-internet-gateway \
  --internet-gateway-id <value>
  --vpc-id $VPC_ID


################
# Route Table
############################
aws ec2 create-route-table \
  --vpc-id $VPC_ID

aws ec2 create-route \
  --route-table-id <value>
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id <value>

aws ec2 associate-route-table \
  --route-table-id <value> \
  --subnet-id <value>

aws ec2 associate-route-table \
  --route-table-id <value> \
  --subnet-id <value>