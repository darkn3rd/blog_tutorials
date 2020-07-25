#!/usr/bin/env bash

## Check for gcloud command
command -v gcloud > /dev/null || \
  { echo 'gcloud command not not found' 1>&2; exit 1; }

## Defaults
MY_CLUSTER_NAME=${1:-"test-cluster"}                  # gke cluster name
MY_REGION=${2:-"us-central1"}                         # default region if not set
MY_PROJECT=${3:-"$(gcloud config get-value project)"} # default project if not set

## Create cluster (1 node per zone)
gcloud container --project $MY_PROJECT clusters create \
  --num-nodes 1 \
  --region $MY_REGION \
  $MY_CLUSTER_NAME
