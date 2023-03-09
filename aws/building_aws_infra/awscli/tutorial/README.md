# AWS VPC Infrastructure 1
## Provisioning Web Service using AWS CLI tools


Some time ago I wrote a small tutorial on how to setup basic infrastructure with a web service and a secured database server on AWS using Terraform.

I wanted to refresh this, as well as have a version of this guide in pure AWS CLI command.
Guides in both AWS CLI and Terraform is useful to see how to interact with AWS and extract information with either tools.

SETUP

# Provision Network Infrastructure

For this part of the exercise, we will create the network infrastructure that includes the subnets and routing.  For brevity, we'll just use the first to Availability Zones.

## Create Virtual Private Cloud

To get started, we'll create the base [VPC](https://aws.amazon.com/vpc/) ([Virtual Private Cloud](https://aws.amazon.com/vpc/)).  After this step, we can add subnets.


```bash
# create VPC
TAG_KEYS="{Key=Name,Value=$USER-vpc},{Key=Site,Value=$USER-web-site}"
TAG_SPEC="ResourceType=vpc,Tags=[$TAG_KEYS]"

# create VPC 
aws ec2 create-vpc \
  --cidr-block "10.0.0.0/16" \
  --tag-specifications $TAG_SPEC

# fetch VPC ID
export VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$USER-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text
)

# create list availability zones for creating subnets
export AZ_ZONES=($(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[*].ZoneName' \
  --output text))
```

## Create Public Subnets

The next step is to create *public subnets* that can have a public IP address.  This means systems can be accessed from the Internet.

```bash
for IDX in {1..2}; do
  TAG_KEYS="{Key=Name,Value=$USER-public$IDX},{Key=Site,Value=$USER-web-site}"
  TAG_SPEC="ResourceType=subnet,Tags=[$TAG_KEYS]"
  AZ_ZONE=$(eval echo ${AZ_ZONES[$((IDX-1))]})

  # create a subnet
  JSON_DATA=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --availability-zone $AZ_ZONE \
    --cidr-block "10.0.$IDX.0/24" \
    --tag-specifications "$TAG_SPEC"
  )

  # extract subnet id from return data
  SUBNET_ID=$(jq -r .Subnet.SubnetId -r <<< $JSON_DATA)
  
  if ! [[ -z $SUBNET_ID ]]; then
    # allow subnet to use public IP addresses
    aws ec2 modify-subnet-attribute \
      --map-public-ip-on-launch \
      --subnet-id $SUBNET_ID
  fi
done
```

## Create Private Subnets

The next step is to create *private subnets*, where systems on this network will not be able to have a public IP address.

```bash
for IDX in {1..2}; do
  TAG_KEYS="{Key=Name,Value=$USER-private$IDX},{Key=Site,Value=$USER-web-site}"
  TAG_SPEC="ResourceType=subnet,Tags=[$TAG_KEYS]"
  AZ_ZONE=$(eval echo ${AZ_ZONES[$((IDX-1))]})

  # create a subnet
  aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --availability-zone $AZ_ZONE \
    --cidr-block "10.0.$((IDX+2)).0/24" \
    --tag-specifications $TAG_SPEC
done
```

## Internet Gateway

In this step, we need to add an Internet gateway so that services in our infrastructure can reach the Internet.  

```bash
# create the Internet gateway
TAG_KEYS="{Key=Name,Value=$USER-igw},{Key=Site,Value=$USER-web-site}"
TAG_SPEC="ResourceType=internet-gateway,Tags=[$TAG_KEYS]"

JSON_DATA=$(aws ec2 create-internet-gateway \
  --tag-specifications $TAG_SPEC)

# extract the Internet gateway id from the previous output
IGW_ID=$(jq -r .InternetGateway.InternetGatewayId <<< $JSON_DATA)

# attach the Internet gateway to the VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID
```

## Create Route Tables

```bash
# create the route table
TAG_KEYS="{Key=Name,Value=$USER-rt},{Key=Site,Value=$USER-web-site}"
TAG_SPEC="ResourceType=route-table,Tags=[$TAG_KEYS]"

JSON_DATA=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications $TAG_SPEC
)

# extract route table id from the previous output
RT_ID=$(jq -r .RouteTable.RouteTableId <<< $JSON_DATA)

# add a route to the route table
aws ec2 create-route \
  --route-table-id $RT_ID \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id $IGW_ID

# associate public subnets to the route table
for IDX in {1..2}; do
  FILTER_TAG="Name=tag:Name,Values=$USER-public$IDX"
  FILTER_VPC="Name=vpc-id,Values=$VPC_ID"

  SUBNET_ID=$(aws ec2 describe-subnets \
    --filter "$FILTER_VPC" "$FILTER_TAG" \
    --query 'Subnets[0].SubnetId' \
    --output text
  )

  aws ec2 associate-route-table \
    --route-table-id $RT_ID \
    --subnet-id $SUBNET_ID
done
```

# Provision Security 
# Provision Backend Database
# Provision Frontend Web Application

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$USER-webserver" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text

```



This way you can compare interacting with AWS cloud from different tools, and improv
