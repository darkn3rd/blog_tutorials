#!/usr/bin/env bash
command -v eksctl > /dev/null || \
  { echo 'eksctl command not not found' 1>&2; exit 1; }

## default settings
MY_CLUSTER_NAME=${1:-"my-demo-cluster"}
MY_REGION=${2:-"us-west-2"}
MY_VERSION=${3:-"1.14"}

## provision eks using eksctl cli
eksctl create cluster \
  --version $MY_VERSION \
  --region $MY_REGION \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --name $MY_CLUSTER_NAME
