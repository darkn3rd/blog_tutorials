#!/usr/bin/env bash
command -v eksctl > /dev/null || \
  { echo 'eksctl command not not found' 1>&2; exit 1; }

## default settings
MY_CLUSTER_NAME=${1:-"my-demo-cluster"}
MY_REGION=${2:-"us-west-2"}

## provision eks using eksctl cli
eksctl delete cluster \
  --region $MY_REGION \
  --name $MY_CLUSTER_NAME \
