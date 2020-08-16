#!/usr/bin/env bash
command -v eksctl > /dev/null || \
  { echo 'eksctl command not not found' 1>&2; exit 1; }

## provision eks using eksctl cli
eksctl delete cluster --config-file "cluster.yaml"
