#!/usr/bin/env bash

../scripts_1/clean_gcp.sh

gcloud iam service-accounts delete $DNS_SA_EMAIL --project $DNS_PROJECT_ID
