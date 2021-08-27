#!/usr/bin/env bash
[[ "$DEBUG" == 1 ]] && set -x

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || { echo "'jq' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${AZ_CLUSTER_NAME}" ]] && { echo 'AZ_CLUSTER_NAME not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${AZ_DNS_DOMAIN}" ]] && { echo 'AZ_DNS_DOMAIN not specified. Aborting' 1>&2 ; exit 1; }

## Create resource (idempotently)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_RESOURCE_GROUP}; then
  [[ -z "$AZ_LOCATION" ]] && { echo 'AZ_LOCATION not specified. Aborting' 1>&2 ; exit 1; }
  az group create --name=${AZ_RESOURCE_GROUP} --location=${AZ_LOCATION}
else
  echo "'$AZ_RESOURCE_GROUP' resource group is already created, skipping."
fi

if az network dns zone list --query "[?name=='$AZ_DNS_DOMAIN'].name" --output tsv | grep -q ${AZ_DNS_DOMAIN}; then
  IDENTITY_NAME=${AZ_DNS_DOMAIN/./-}

  az identity create \
    --resource-group ${AZ_RESOURCE_GROUP} \
    --name ${IDENTITY_NAME}

  # Gets principalId to use for role assignment
  IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query principalId -o tsv)
  export IDENTITY_CLIENT_ID=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query clientId -o tsv)
  IDENTITY_SCOPE=$(az identity show --resource-group ${AZ_RESOURCE_GROUP} --name ${IDENTITY_NAME} --query id -o tsv)
  AZ_DNS_SCOPE=$(az network dns zone show --name ${AZ_DNS_DOMAIN} --resource-group ${AZ_RESOURCE_GROUP} --query id -o tsv)

  az role assignment create \
    --assignee "$IDENTITY_PRINCIPAL_ID" \
    --role "DNS Zone Contributor" \
    --scope "$AZ_DNS_SCOPE"
else
  echo "Cannot find '${AZ_DNS_DOMAIN}' zone, aborting." 1>&2
  exit 1
fi

if az group list --query "[].name" -o tsv | grep -q ${AZ_RESOURCE_GROUP}; then
  ## check if AKS cluster was already created
  if az aks list --query "[].name" -o tsv | grep -q ${AZ_CLUSTER_NAME}; then
    export POD_IDENTITY_NAME=${AZ_DNS_DOMAIN/./-}
    export POD_IDENTITY_NAMESPACE="kube_addons"

    az aks pod-identity add \
      --resource-group myResourceGroup \
      --cluster-name ${AZ_CLUSTER_NAME} \
      --namespace ${POD_IDENTITY_NAMESPACE}  \
      --name ${POD_IDENTITY_NAME} \
      --identity-resource-id ${IDENTITY_CLIENT_ID}
  else
    echo "Cannot find '${AZ_CLUSTER_NAME}' Kubernetes cluster. Aborting." 1>&2
    exit 1
  fi
fi
