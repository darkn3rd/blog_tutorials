#!/usr/bin/env bash
[[ "$DEBUG" == 1 ]] && set -x
## Check for required commands
command -v az > /dev/null || \
  { echo "'az' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || \
  { echo "'jq' command not not found" 1>&2; exit 1; }

## Verify these variables are set
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "$AZ_ACR_NAME" ]] && { echo 'AZ_ACR_NAME not specified. Aborting' 1>&2 ; exit 1; }

## create resource (idempotently)
if ! az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  [[ -z "$AZ_LOCATION" ]] && { echo 'AZ_LOCATION not specified. Aborting' 1>&2 ; exit 1; }
  az group create --name=${AZ_RESOURCE_GROUP} --location=${AZ_LOCATION}
else
  echo "'$AZ_RESOURCE_GROUP' resource group is already created, skipping."
fi

## create acr if resource group was created
if az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  if ! az acr list | jq '.[].loginServer' -r | grep -q ${AZ_ACR_NAME}; then
    az acr create \
      --resource-group ${AZ_RESOURCE_GROUP} \
      --name ${AZ_ACR_NAME} \
      --sku Basic
  else
    echo "'$AZ_ACR_NAME' container registry is already created, skipping."
  fi
fi
