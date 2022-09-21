#!/usr/bin/env bash
source env.sh

# Grant local docker access to GCR
gcloud auth configure-docker

# Grant read permissions explicitly GCS storage used for GCR
# Docs: https://cloud.google.com/storage/docs/access-control/using-iam-permissions#gsutil
gsutil iam ch \
  serviceAccount:$GKE_SA_EMAIL:objectViewer \
  gs://artifacts.$GCR_PROJECT_ID.appspot.com
