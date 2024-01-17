#!/usr/bin/env bash

## Check for required commands
command -v gcloud > /dev/null || { echo "'gcloud' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${GKE_PROJECT_ID}" ]] && { echo '"GKE_PROJECT_ID" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_CLUSTER_NAME}" ]] && { echo '"GKE_CLUSTER_NAME" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_REGION}" ]] && { echo '"GKE_REGION" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_MACHINE_TYPE}" ]] && { echo '"GKE_MACHINE_TYPE" not specified. Aborting' 1>&2 ; exit 1; }

[[ -z "${GKE_SA_NAME}" ]] && { echo '"GKE_SA_NAME" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_PROJECT_ID}" ]] && { echo '"GKE_PROJECT_ID" not specified. Aborting' 1>&2 ; exit 1; }
GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

[[ -z "${GKE_NETWORK_NAME}" ]] && { echo '"GKE_NETWORK_NAME" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_SUBNET_NAME}" ]] && { echo '"GKE_SUBNET_NAME" not specified. Aborting' 1>&2 ; exit 1; }

gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION \
  --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --machine-type $GKE_MACHINE_TYPE \
  --enable-ip-alias \
  --enable-network-policy \
  --enable-private-nodes \
  --no-enable-master-authorized-networks \
  --master-ipv4-cidr 172.16.0.32/28 \
  --network $GKE_NETWORK_NAME \
  --subnetwork $GKE_SUBNET_NAME \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"
