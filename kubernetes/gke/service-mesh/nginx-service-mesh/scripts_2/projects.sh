#!/usr/bin/env bash

# enable billing and APIs for DNS project if not done already
gcloud projects create $DNS_PROJECT_ID
gcloud config set project $DNS_PROJECT_ID
gcloud beta billing projects link $DNS_PROJECT_ID \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "dns.googleapis.com"
