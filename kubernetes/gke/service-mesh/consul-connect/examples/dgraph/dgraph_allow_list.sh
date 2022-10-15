#!/usr/bin/env bash
DG_ALLOW_LIST=$(gcloud container clusters  describe $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION \
  --format json \
  | jq -r '.clusterIpv4Cidr,.servicesIpv4Cidr' \
  | tr '\n' ','
)
export MY_IP_ADDRESS=$(curl --silent ifconfig.me)
export DG_ALLOW_LIST="${DG_ALLOW_LIST}${MY_IP_ADDRESS}/32"
