#!/usr/bin/env bash
[[ "$DEBUG" == 1 ]] && set -x

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "$AZ_AKS_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }

if az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN'].name" --output tsv | grep -q ${AZ_DNS_DOMAIN}; then
  AZ_DNS_SCOPE=$(
    az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN'].id" --output tsv
  )

  # get kublet id
  AZ_PRINCIPAL_ID=$(
    az aks show -g $AZ_AKS_RESOURCE_GROUP -n $AZ_AKS_CLUSTER_NAME \
      --query "identityProfile.kubeletidentity.objectId" --output tsv
  )

  # attach role for DNS zone to kublet id
  az role assignment create \
    --assignee "$AZ_PRINCIPAL_ID" \
    --role "DNS Zone Contributor" \
    --scope "$AZ_DNS_SCOPE"

else
  echo "Cannot find '${AZ_DNS_DOMAIN}' zone, aborting."
  exit 1
fi
