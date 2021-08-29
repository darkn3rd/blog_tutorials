#!/usr/bin/env bash

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${AZ_RESOURCE_GROUP}" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${AZ_CLUSTER_NAME}" ]] && { echo 'AZ_CLUSTER_NAME not specified. Aborting' 1>&2 ; exit 1; }

## Opinionated defaults
IDENTITY_NAME=${AZ_DNS_DOMAIN/./-}-identity
POD_IDENTITY_NAMESPACE="kube-addons"
POD_IDENTITY_NAME="external-dns"

if az group list --query "[].name" -o tsv | grep -q ${AZ_RESOURCE_GROUP}; then
  ## check if AKS cluster was already created
  if az aks list --query "[].name" -o tsv | grep -q ${AZ_CLUSTER_NAME}; then
    ## Check if identity exist
    if az identity list --query "[].name" -o tsv | grep -q ${IDENTITY_NAME}; then
      ## Fetch the scope path to the identity (aka resource id)
      IDENTITY_RESOURCE_ID=$(az identity show \
        --resource-group ${AZ_RESOURCE_GROUP} \
        --name ${IDENTITY_NAME} \
        --query id \
        --output tsv
      )
    else
      echo "'$IDENTITY_NAME' identity not found. Aborting" 1>&2
      exit 1
    fi

    # ## Bind managed identity to the target pod
    az aks pod-identity add \
      --resource-group ${AZ_RESOURCE_GROUP}  \
      --cluster-name ${AZ_CLUSTER_NAME} \
      --namespace ${POD_IDENTITY_NAMESPACE} \
      --name ${POD_IDENTITY_NAME} \
      --identity-resource-id ${IDENTITY_RESOURCE_ID}
  else
    echo "Cannot find '${AZ_CLUSTER_NAME}' Kubernetes cluster. Aborting." 1>&2
    exit 1
  fi
else
  echo "Cannot find '${AZ_RESOURCE_GROUP}' resource group. Aborting." 1>&2
  exit 1
fi
