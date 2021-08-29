#!/usr/bin/env bash
[[ "${DEBUG}" == 1 ]] && set -x

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "${AZ_RESOURCE_GROUP}" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "${AZ_CLUSTER_NAME}" ]] && { echo 'AZ_CLUSTER_NAME not specified. Aborting' 1>&2 ; exit 1; }

## Default variables
AZ_VM_SIZE=${AZ_VM_SIZE:-Standard_DS2_v2}
KUBECONFIG=${KUBECONFIG:-${HOME}/.kube/${AZ_CLUSTER_NAME}.yaml}

## Create the resource group (idempotently)
if ! az group list --query "[].name" -o tsv | grep -q ${AZ_RESOURCE_GROUP}; then
  [[ -z "${AZ_LOCATION}" ]] && { echo 'AZ_LOCATION not specified. Aborting' 1>&2 ; exit 1; }
  az group create --name=${AZ_RESOURCE_GROUP} --location=${AZ_LOCATION}
else
  echo "'${AZ_RESOURCE_GROUP}' resource group is already created, skipping."
fi

## create aks cluster if resource group was created
if az group list --query "[].name" -o tsv | grep -q ${AZ_RESOURCE_GROUP}; then
  ## check if AKS cluster was already created
  if az aks list --query "[].name" -o tsv | grep -q ${AZ_CLUSTER_NAME}; then
    echo "Installing Pod Identity on '${AZ_CLUSTER_NAME}' Kubernetes cluster"
    az aks update \
      --resource-group ${AZ_RESOURCE_GROUP} \
      --name ${AZ_CLUSTER_NAME} \
      --enable-pod-identity
  else
    echo "'${AZ_CLUSTER_NAME}' Kubernetes cluster is not found. Exiting"
    exit 1
  fi
fi
