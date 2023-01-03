#!/usr/bin/env bash

################
# Web Security Group
############################
aws ec2 create-security-group \
 --group-name "webserver" \
 --description "Allow HTTP from Anywhere" \
 --vpc-id $VPC_ID \
 --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$USER-webserver},{Key=Site,Value=$USER-web-site}]"

WEB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=$USER-webserver" \
  --query "SecurityGroups[0].GroupId" \
  --output text
)

aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --port 80 \
  --cidr "0.0.0.0/0" \
  --protocol "tcp"

################
# Database Security Group
############################
aws ec2 create-security-group \
 --group-name "database" \
 --description "Allow MySQL/Aurora from WebService" \
 --vpc-id $VPC_ID \
 --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$USER-database},{Key=Site,Value=$USER-web-site}]"

DB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=$USER-database" \
  --query "SecurityGroups[0].GroupId" \
  --output text
)

aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG_ID \
  --port 3306 \
  --cidr "0.0.0.0/0" \
  --protocol "tcp" \
  --source-group $WEB_SG_ID
