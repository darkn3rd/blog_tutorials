#!/usr/bin/env bash

################
# Fetch AMI image for this region
# NOTE: 
#  - each region has a unique AMI ID for the same images
#  - exhaustive search required  
############################
OWNER_ID="137112412989" # Amazon
AMI_IMAGE_ID=$(aws ec2 describe-images \
  --filters \
    "Name=name,Values=amzn2-ami-*-gp2" \
    "Name=owner-id,Values=$OWNER_ID" \
    "Name=virtualization-type,Values=hvm" \
    "Name=architecture,Values=x86_64" \
  --query 'Images[*].[ImageId,CreationDate]' \
  --output text \
  | sort -k2 -r \
  | head -n1 \
  | cut -f1
)

SUBNET_ID=$(aws ec2 describe-subnets \
  --filter "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$USER-public1" \
  --query 'Subnets[0].SubnetId' \
  --output text
)

WEB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=$USER-webserver" \
  --query "SecurityGroups[0].GroupId" \
  --output text
)


TAG_KEYS="{Key=Name,Value=$USER-webserver},{Key=Site,Value=$USER-web-site}"
TAG_SPEC="ResourceType=instance,Tags=[$TAG_KEYS]"

aws ec2 run-instances \
  --image-id $AMI_IMAGE_ID \
  --count 1 \
  --instance-type "t2.micro" \
  --security-group-ids $WEB_SG_ID \
  --subnet-id $SUBNET_ID \
  --user-data file://user_data.sh \
  --associate-public-ip-address \
  --tag-specifications $TAG_SPEC


aws ec2 run-instances \
  --image-id $AMI_IMAGE_ID \
  --count 1 \
  --instance-type "t2.micro" \
  --security-group-ids $WEB_SG_ID \
  --subnet-id $SUBNET_ID \
  --user-data file://user_data.sh \
  --associate-public-ip-address \
  --tag-specifications $TAG_SPEC \
  --key-name joaquin-key

--key-name

aws ec2 run-instances \
  --image-id $AMI_IMAGE_ID \
  --count 1 \
  --instance-type "t2.micro" \
  --security-group-ids $WEB_SG_ID \
  --subnet-id $SUBNET_ID \
  --user-data file:///Users/joaquin/area51/proj/blog_tutorials/aws/building_aws_infra/awscli/user_data.sh \
  --associate-public-ip-address \
  --tag-specifications $TAG_SPEC