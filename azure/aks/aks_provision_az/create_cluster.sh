#!/usr/bin/env bash
set -x
## Check for gcloud command
command -v az > /dev/null || \
  { echo "'az' command not not found" 1>&2; exit 1; }

## Defaults
AZ_VM_SIZE=${AZ_VM_SIZE:-Standard_DS2_v2}
KUBECONFIG=${KUBECONFIG:-$HOME/.kube/config}

## Verify these variables are set
[[ -z "$AZ_LOCATION" ]] && { echo 'AZ_LOCATION not specified. Aborting' 2>&1 ; exit 1; }
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 2>&1 ; exit 1; }
[[ -z "$AZ_CLUSTER_NAME" ]] && { echo 'AZ_CLUSTER_NAME not specified. Aborting' 2>&1 ; exit 1; }

## create resource (idempotently)
if ! az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  az group create --name=${AZ_RESOURCE_GROUP} --location=${AZ_LOCATION}
fi

## create aks cluster if resource group was created
if az group list | jq '.[].name' -r | grep -q ${AZ_RESOURCE_GROUP}; then
  if ! az aks list | jq '.[].name' -r | grep -q ${AZ_CLUSTER_NAME}; then
    az aks create \
        --resource-group ${AZ_RESOURCE_GROUP} \
        --name ${AZ_CLUSTER_NAME} \
        --generate-ssh-keys \
        --vm-set-type VirtualMachineScaleSets \
        --node-vm-size $AZ_VM_SIZE \
        --load-balancer-sku standard \
        --node-count 3 \
        --zones 1 2 3
    fi

  if az aks list | jq '.[].name' -r | grep -q ${AZ_CLUSTER_NAME}; then
    ## Azure ignores KUBECONFIG, but we can specify with --file flag
    az aks get-credentials \
      --resource-group ${AZ_RESOURCE_GROUP} \
      --name ${AZ_CLUSTER_NAME} \
      --file ${KUBECONFIG}
  fi
fi
