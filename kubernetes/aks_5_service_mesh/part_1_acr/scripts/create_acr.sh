#!/usr/bin/env bash

## Verify required commands
command -v az > /dev/null || \
  { echo "[ERROR]: 'az' command not not found" 1>&2; exit 1; }

## Verify these variables are set
[[ -z "$AZ_RESOURCE_GROUP" ]] && { echo 'AZ_RESOURCE_GROUP not specified. Aborting' 2>&1 ; exit 1; }
[[ -z "$AZ_ACR_NAME" ]] && { echo 'AZ_ACR_NAME not specified. Aborting' 2>&1 ; exit 1; }

az acr create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_ACR_NAME} \
  --sku Basic
