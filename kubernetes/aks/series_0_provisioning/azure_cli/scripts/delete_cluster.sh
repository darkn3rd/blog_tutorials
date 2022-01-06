#!/usr/bin/env bash

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "$AZ_AKS_RESOURCE_GROUP" ]] && { echo 'AZ_AKS_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "$AZ_AKS_CLUSTER_NAME" ]] && { echo 'AZ_AKS_CLUSTER_NAME not specified. Aborting' 1>&2 ; exit 1; }

## delete aks cluster if resource group was created
if az group list --query "[].name" -o tsv | grep -q "^${AZ_AKS_RESOURCE_GROUP}$"; then
  if az aks list --query "[].name" -o tsv | grep -q "^${AZ_AKS_CLUSTER_NAME}$"; then
    az aks delete \
     --resource-group "${AZ_AKS_RESOURCE_GROUP}" \
     --name "${AZ_AKS_CLUSTER_NAME}"
  else
    echo "Cannot find '$AZ_AKS_CLUSTER_NAME' Kubernetes cluster, skipping."
  fi
fi
