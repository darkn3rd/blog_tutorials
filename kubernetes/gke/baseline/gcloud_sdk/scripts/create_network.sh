#!/usr/bin/env bash

## Check for required commands
command -v gcloud > /dev/null || { echo "'gcloud' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${GKE_REGION}" ]] && { echo '"GKE_REGION" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_PROJECT_ID}" ]] && { echo '"GKE_PROJECT_ID" not specified. Aborting' 1>&2 ; exit 1; }

[[ -z "${GKE_NETWORK_NAME}" ]] && { echo '"GKE_NETWORK_NAME" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_SUBNET_NAME}" ]] && { echo '"GKE_SUBNET_NAME" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_ROUTER_NAME}" ]] && { echo '"GKE_ROUTER_NAME" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_NAT_NAME}" ]] && { echo '"GKE_NAT_NAME" not specified. Aborting' 1>&2 ; exit 1; }


#######################
# create VPC for target region
#######################################
gcloud compute networks create $GKE_NETWORK_NAME \
  --project $GKE_PROJECT_ID \
  --subnet-mode=custom \
  --mtu=1460 \
  --bgp-routing-mode=regional

#######################
# create subnet (spanning all availability zones w/i region)
#######################################
gcloud compute networks subnets create $GKE_SUBNET_NAME \
  --project $GKE_PROJECT_ID \
  --network=$GKE_NETWORK_NAME \
  --range=10.10.0.0/24 \
  --region=$GKE_REGION \
  --enable-private-ip-google-access

#######################
# add support for outbound traffic
#######################################
gcloud compute routers create $GKE_ROUTER_NAME \
  --project $GKE_PROJECT_ID \
  --network=$GKE_NETWORK_NAME \
  --region=$GKE_REGION

gcloud compute routers nats create $GKE_NAT_NAME \
  --project $GKE_PROJECT_ID \
  --router=$GKE_ROUTER_NAME \
  --region=$GKE_REGION \
  --nat-custom-subnet-ip-ranges=$GKE_SUBNET_NAME \
  --auto-allocate-nat-external-ips
