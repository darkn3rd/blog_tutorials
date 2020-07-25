#!/usr/bin/env bash

## Check for gcloud command
command -v gcloud > /dev/null || \
  { echo 'gcloud command not not found' >&2; exit 1; }

## Check for arguments
if (( $# < 1 )); then
  printf "   Usage: $0 <CLOUD_DNS_ZONE_NAME> [GCP_PROJECT_NAME]\n\n" >&2
  exit 1
fi

## Local Variables
MY_ZONE=${1}
MY_PROJECT=${2:-"$(gcloud config get-value project)"} # default project if not set

## Print Zone Records
gcloud dns record-sets list \
 --project $MY_PROJECT \
 --zone $MY_ZONE \
 --filter "type=NS OR type=SOA" \
 --format json
 