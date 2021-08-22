#!/usr/bin/env bash
[[ "$DEBUG" == 1 ]] && set -x

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || { echo "'jq' command not not found" 1>&2; exit 1; }

## Check for required variables
[[ -z "$AZ_LOCATION" ]] && { echo 'AZ_LOCATION not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "$AZ_CLUSTER_NAME" ]] && { echo 'AZ_CLUSTER_NAME not specified. Aborting' 1>&2 ; exit 1; }
[[ -z "$AZ_ACR_NAME" ]] && { echo 'AZ_ACR_NAME not specified. Aborting' 1>&2 ; exit 1; }

## Default variables
AZ_VM_SIZE=${AZ_VM_SIZE:-Standard_DS2_v2}
KUBECONFIG=${KUBECONFIG:-$HOME/.kube/${AZ_CLUSTER_NAME}.yaml}

## create resource (idempotently)
if ! az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  az group create --name=${AZ_RESOURCE_GROUP} --location=${AZ_LOCATION}
else
  echo "'$AZ_RESOURCE_GROUP' resource group is already created, skipping."
fi

## fetch acr login server
if az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  if az acr list | jq '.[].loginServer' -r | grep -q ${AZ_ACR_NAME}; then
    export AZ_ACR_LOGIN_SERVER=$(az acr list \
      --resource-group ${AZ_RESOURCE_GROUP} \
      --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
      --output tsv
    )
  else
    echo "Cannot find '${AZ_ACR_NAME}' container registry, aborting."
    exit 1
  fi
fi

## create aks cluster if resource group was created
if az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  ## check if AKS cluster was already created
  if ! az aks list | jq '.[].name' -r | grep -q ${AZ_CLUSTER_NAME}; then
    echo "Creating '$AZ_CLUSTER_NAME' Kubernetes cluster with support for 'AZ_ACR_NAME' container registry."
    az aks create \
        --resource-group ${AZ_RESOURCE_GROUP} \
        --name ${AZ_CLUSTER_NAME} \
        --generate-ssh-keys \
        --vm-set-type VirtualMachineScaleSets \
        --node-vm-size $AZ_VM_SIZE \
        --load-balancer-sku standard \
        --enable-managed-identity \
        --attach-acr ${AZ_ACR_NAME} \
        --node-count 3 \
        --zones 1 2 3
  else
    echo "'$AZ_CLUSTER_NAME' Kubernetes cluster is already created, skipping."
  fi

  ## create KUBECONFIG so that cluster can be accessed using existing login credentials
  if az aks list | jq '.[].name' -r | grep -q ${AZ_CLUSTER_NAME}; then
    ## Azure ignores KUBECONFIG, but we can specify with --file flag
    az aks get-credentials \
      --resource-group ${AZ_RESOURCE_GROUP} \
      --name ${AZ_CLUSTER_NAME} \
      --file ${KUBECONFIG}
  fi
fi
