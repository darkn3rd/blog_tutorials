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
# list of minimal required roles
#######################################
ROLES=(
  roles/logging.logWriter
  roles/monitoring.metricWriter
  roles/monitoring.viewer
  roles/stackdriver.resourceMetadata.writer
)

#######################
# create google service account principal
#######################################
gcloud iam service-accounts create $GKE_SA_NAME \
  --display-name $GKE_SA_NAME --project $GKE_PROJECT_ID

#######################
# assign google service account to roles in GKE project
#######################################
for ROLE in ${ROLES[*]}; do
  gcloud projects add-iam-policy-binding $GKE_PROJECT_ID \
    --member "serviceAccount:$GKE_SA_EMAIL" \
    --role $ROLE \
    --no-user-output-enabled \
    --quiet
done

cat << EOF
bindings:
$(for ROLE in ${ROLES[*]}; do printf "%s\n  %s\n  %s\n" \
  "- members:" \
  "- serviceAccount:$GKE_SA_EMAIL" \
  "role: $ROLE"
done)
EOF
