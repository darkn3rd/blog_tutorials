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

## Delete network infra
gcloud compute routers nats delete $GKE_NAT_NAME --router $GKE_ROUTER_NAME --project $GKE_PROJECT_ID
gcloud compute routers delete $GKE_ROUTER_NAME --project $GKE_PROJECT_ID
gcloud compute networks subnets delete $GKE_SUBNET_NAME --project $GKE_PROJECT_ID
gcloud compute networks delete $GKE_NETWORK_NAME --project $GKE_PROJECT_ID
