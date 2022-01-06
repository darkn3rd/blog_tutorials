#!/usr/bin/env bash
[[ "$DEBUG" == 1 ]] && set -x

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "$AZ_DNS_RESOURCE_GROUP" ]] && { echo 'AZ_DNS_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "$AZ_DNS_DOMAIN" ]] && { echo 'AZ_DNS_DOMAIN not specified. Aborting' 1>&2 ; exit 1; }

## Create resource (idempotently)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_DNS_RESOURCE_GROUP}; then
  [[ -z "$AZ_DNS_LOCATION" ]] && { echo 'AZ_DNS_LOCATION not specified. Aborting' 1>&2 ; exit 1; }
  az group create --name=${AZ_DNS_RESOURCE_GROUP} --location=${AZ_DNS_LOCATION}
else
  echo "'$AZ_DNS_RESOURCE_GROUP' resource group is already created, skipping."
fi

if ! az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN'].name" --output tsv | grep -q ${AZ_DNS_DOMAIN}; then
  az network dns zone create \
    --resource-group ${AZ_DNS_RESOURCE_GROUP} \
    --name ${AZ_DNS_DOMAIN}
else
  echo "'$AZ_DNS_DOMAIN' zone is already exist, skipping."
fi
