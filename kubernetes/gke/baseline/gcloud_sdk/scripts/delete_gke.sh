#!/usr/bin/env bash

## Check for required commands
command -v gcloud > /dev/null || { echo "'gcloud' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${GKE_PROJECT_ID}" ]] && { echo '"GKE_PROJECT_ID" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_CLUSTER_NAME}" ]] && { echo '"GKE_CLUSTER_NAME" not specified. Aborting' 1>&2 ; exit 1; }

## Delete GKE
gcloud container clusters delete $GKE_CLUSTER_NAME --project $GKE_PROJECT_ID
