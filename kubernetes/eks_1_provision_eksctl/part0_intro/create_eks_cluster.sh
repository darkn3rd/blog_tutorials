#!/usr/bin/env bash
command -v eksctl > /dev/null || \
  { echo 'eksctl command not not found' 1>&2; exit 1; }

eksctl create cluster \
  --version 1.14 \
  --region us-west-2 \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --name my-demo
