#!/usr/bin/env bash
source env.sh

# Google Cloud Resources
gcloud container clusters delete $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION

gcloud iam service-accounts delete $GKE_SA_EMAIL --project $GKE_PROJECT_ID
