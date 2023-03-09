#!/usr/bin/env bash

PRIV1_SUBNET_ID=$(aws ec2 describe-subnets \
  --filter "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$USER-private1" \
  --query 'Subnets[0].SubnetId' \
  --output text
)

PRIV2_SUBNET_ID=$(aws ec2 describe-subnets \
  --filter "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$USER-private2" \
  --query 'Subnets[0].SubnetId' \
  --output text
)

SUBNET_IDS=()
for IDX in {1..2}; do
  PRIV1_SUBNET_ID=$(aws ec2 describe-subnets \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$USER-private$IDX" \
    --query 'Subnets[0].SubnetId' \
    --output text
  )

  SUBNET_IDS+=("\"$PRIV1_SUBNET_ID\"")
done

aws rds create-db-subnet-group \
  --db-subnet-group-name "$USER-dbsg" \
  --db-subnet-group-description "$USER-dbsg" \
  --subnet-ids "[$(tr ' ' ',' <<< ${SUBNET_IDS[@]})]" \
  --tags "Key=Name,Value=$USER-dbsg" \
  --tags "Key=Site,Value=$USER-web-site"


aws rds create-db-subnet-group \
  --db-subnet-group-name "$USER-dbsg" \
  --db-subnet-group-description "$USER-dbsg" \
  --subnet-ids "[\"$PRIV1_SUBNET_ID\", \"$PRIV2_SUBNET_ID\"]" \
  --tags "Key=Name,Value=$USER-dbsg" \
  --tags "Key=Site,Value=$USER-web-site"

DB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=$USER-database" \
  --query "SecurityGroups[0].GroupId" \
  --output text
)

aws rds create-db-instance \
  --db-instance-identifier "$USER-db" \
  --db-instance-class "db.t3.micro" \
  --engine "mysql" \
  --engine-version "5.7.40" \
  --storage-type "gp2" \
  --allocated-storage 20 \
  --db-name "webdb" \
  --master-username "admin" \
  --master-user-password 'sekret99' \
  --db-parameter-group-name "default.mysql5.7" \
  --db-subnet-group-name "$USER-dbsg" \
  --vpc-security-group-ids "$DB_SG_ID" \
  --backup-retention-period 0 \
  --tags "Key=Name,Value=$USER-db" \
  --tags "Key=Site,Value=$USER-web-site"
