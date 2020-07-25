#!/usr/bin/env bash

## Check for gcloud command
command -v gcloud > /dev/null || \
  {echo 'gcloud command not not found' 1>&2; exti 1}

## Desired scopes - default + CloudDNS access
SCOPES=("https://www.googleapis.com/auth/devstorage.read_only"
        "https://www.googleapis.com/auth/logging.write"
        "https://www.googleapis.com/auth/monitoring"
        "https://www.googleapis.com/auth/servicecontrol"
        "https://www.googleapis.com/auth/service.management.readonly"
        "https://www.googleapis.com/auth/trace.append"
        "https://www.googleapis.com/auth/ndev.clouddns.readwrite"
)

## Defaults
MY_SCOPES=$(IFS=,; echo "${SCOPES[*]}")               # scope list (command seperated)
MY_CLUSTER_NAME=${1:-"test-cluster"}                  # gke cluster name
MY_REGION=${2:-"us-central1"}                         # default region if not set
MY_PROJECT=${3:-"$(gcloud config get-value project)"} # default project if not set
GKE_VERSION="1.14.10-gke.36"

## Create GKE Cluster
gcloud container --project $MY_PROJECT clusters create \
  --cluster-version $GKE_VERSION \
  --region $MY_REGION \
  --machine-type n1-standard-1 \
  --num-nodes 1 \
  --min-nodes 2 \
  --max-nodes 4 \
  --scopes $MY_SCOPES \
  $MY_CLUSTER_NAME
