#!/usr/bin/env bash

## Check for required commands
command -v gcloud > /dev/null || { echo "'gcloud' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${GKE_PROJECT_ID}" ]] && { echo 'GKE_PROJECT_ID not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${ClOUD_BILLING_ACCOUNT}" ]] && { echo 'ClOUD_BILLING_ACCOUNT not specified. Aborting' 1>&2 ; exit 1; }

# create new project
gcloud projects create $GKE_PROJECT_ID

# set up billing to the GKE project
gcloud beta billing projects link $GKE_PROJECT_ID \
  --billing-account $ClOUD_BILLING_ACCOUNT

# authorize APIs for GKE project
gcloud config set project $GKE_PROJECT_ID
gcloud services enable "compute.googleapis.com"
gcloud services enable "container.googleapis.com"
