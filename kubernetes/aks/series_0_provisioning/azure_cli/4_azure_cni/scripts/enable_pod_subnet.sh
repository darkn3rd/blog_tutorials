#!/usr/bin/env bash

## Check for required commands
command -v az > /dev/null || { echo "'az' command not not found" 1>&2; exit 1; }

az feature register --name PodSubnetPreview --namespace Microsoft.ContainerService
az extension add --name aks-preview
az extension update --name aks-preview
az provider register --namespace Microsoft.ContainerService
