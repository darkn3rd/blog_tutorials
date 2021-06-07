#!/usr/bin/env bash

## Check for gcloud command
command -v az > /dev/null || \
  { echo "'az' command not not found" 1>&2; exit 1; }

## Defaults
AZ_RESOURCE_GROUP=${AZ_RESOURCE_GROUP}
AZ_CLUSTER_NAME=${AZ_CLUSTER_NAME}

## Verify these variables are set
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 2>&1 ; exit 1; }
[[ -z "$AZ_CLUSTER_NAME" ]] && { echo 'AZ_CLUSTER_NAME not specified. Aborting' 2>&1 ; exit 1; }

## create aks cluster if resource group was created
if az group list | jq '.[].name' -r | grep -q "^${AZ_RESOURCE_GROUP}$"; then
  if az aks list | jq '.[].name' -r | grep -q "^${AZ_CLUSTER_NAME}$"; then
    az aks delete \
     --resource-group "${AZ_RESOURCE_GROUP}" \
     --name "${AZ_CLUSTER_NAME}" 
  fi
fi

