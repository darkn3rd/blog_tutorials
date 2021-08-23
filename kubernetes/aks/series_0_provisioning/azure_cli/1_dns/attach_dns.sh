#!/usr/bin/env bash
[[ "$DEBUG" == 1 ]] && set -x

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || { echo "'jq' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }

## Create resource (idempotently)
if ! az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  [[ -z "$AZ_LOCATION" ]] && { echo 'AZ_LOCATION not specified. Aborting' 1>&2 ; exit 1; }
  az group create --name=${AZ_RESOURCE_GROUP} --location=${AZ_LOCATION}
else
  echo "'$AZ_RESOURCE_GROUP' resource group is already created, skipping."
fi

if az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN'].name" --output tsv | grep -q ${AZ_DNS_DOMAIN}; then
  AZ_DNS_SCOPE=$(
    az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN'].id" --output tsv
  )

  AZ_PRINCIPAL_ID=$(
    az aks show -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME \
      --query "identityProfile.kubeletidentity.objectId" --output tsv
  )

  az role assignment create \
    --assignee "$AZ_PRINCIPAL_ID" \
    --role "DNS Zone Contributor" \
    --scope "$AZ_DNS_SCOPE"

else
  echo "Cannot find '${AZ_DNS_DOMAIN}' zone, aborting."
  exit 1
fi





export AZ_DNS_SCOPE=$(
  az network dns zone list \
    --query "[?name=='$AZ_DNS_DOMAIN'].id" \
    --output table | tail -1
)
export AZ_PRINCIPAL_ID=$(
  az aks show -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" | tr -d '"'
)
az role assignment create \
  --assignee "$AZ_PRINCIPAL_ID" \
  --role "DNS Zone Contributor" \
  --scope "$AZ_DNS_SCOPE"
