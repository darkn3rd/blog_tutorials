#!/usr/bin/env bash

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
  --network-plugin azure \
  --network-policy calico \
  --node-count 3 \
  --zones 1 2 3

az aks get-credentials \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --file ${KUBECONFIG:-"$HOME/.kube/${AZ_CLUSTER_NAME}.yaml"}
