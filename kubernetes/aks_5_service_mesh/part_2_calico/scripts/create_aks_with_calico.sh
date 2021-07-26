#!/usr/bin/env bash

## Verify required commands
command -v az > /dev/null || \
  { echo "[ERROR]: 'az' command not not found" 1>&2; exit 1; }

## Verify these variables are set
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 2>&1 ; exit 1; }
[[ -z "$AZ_CLUSTER_NAME" ]] && { echo 'AZ_CLUSTER_NAME not specified. Aborting' 2>&1 ; exit 1; }

az aks create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --generate-ssh-keys \
  --vm-set-type VirtualMachineScaleSets \
  --node-vm-size ${AZ_VM_SIZE:-"Standard_DS2_v2"} \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin ${AZ_NET_PLUGIN:-"kubenet"} \
  --network-policy ${AZ_NET_POLICY:-""} \
  --attach-acr ${AZ_ACR_NAME} \
  --node-count 3 \
  --zones 1 2 3

az aks get-credentials \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --file ${KUBECONFIG:-"$HOME/.kube/${AZ_CLUSTER_NAME}.yaml"}
