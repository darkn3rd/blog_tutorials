#!/usr/bin/env bash
export AZ_PRINCIPAL_ID=$(
  az aks show -g $AZ_RESOURCE_GROUP -n $AZ_CLUSTER_NAME \
    --query "identityProfile.kubeletidentity.objectId" | tr -d '"'
)

export AZ_DNS_SCOPE=$(
  az network dns zone list \
    --query "[?name=='$AZ_DNS_DOMAIN'].id" \
    --output table | tail -1
)

az role assignment create \
  --assignee "$AZ_PRINCIPAL_ID" \
  --role "DNS Zone Contributor" \
  --scope  "$AZ_DNS_SCOPE"
