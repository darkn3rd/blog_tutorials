#!/usr/bin/env bash

## Check for required commands
command -v gcloud > /dev/null || { echo "'gcloud' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${GKE_SA_NAME}" ]] && { echo '"GKE_SA_NAME" not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${GKE_PROJECT_ID}" ]] && { echo '"GKE_PROJECT_ID" not specified. Aborting' 1>&2 ; exit 1; }

## Variables Used
GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"

gcloud config set project $GKE_PROJECT_ID

#######################
# list of roles configured earlier
#######################################
ROLES=(
  roles/logging.logWriter
  roles/monitoring.metricWriter
  roles/monitoring.viewer
  roles/stackdriver.resourceMetadata.writer
)

#######################
# remove service account from roles
#######################################
for ROLE in ${ROLES[*]}; do
  gcloud projects remove-iam-policy-binding $GKE_PROJECT_ID \
    --member "serviceAccount:$GKE_SA_EMAIL" \
    --role $ROLE
done

#######################
# delete gsa
#######################################
gcloud iam service-accounts delete $GKE_SA_EMAIL --project $GKE_PROJECT_ID
