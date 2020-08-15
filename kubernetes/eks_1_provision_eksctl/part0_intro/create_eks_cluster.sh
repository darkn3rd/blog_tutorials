#!/usr/bin/env bash

eksctl create cluster \
  --version 1.14 \
  --region us-west-2 \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --name my-demo
