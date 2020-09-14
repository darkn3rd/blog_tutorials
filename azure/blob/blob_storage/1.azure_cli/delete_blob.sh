#!/usr/bin/env bash

## Check for Azure CLI command
command -v az > /dev/null || \
  { echo "'az' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || \
  { echo "'jq' command not not found" 1>&2; exit 1; }

## Defaults
MY_CONTAINER_NAME=${MY_CONTAINER_NAME:-$1}

if [[ -z "${MY_CONTAINER_NAME}" ]]; then
  if (( $# < 1 )); then
    printf "ERROR: Need at least one parameter or define 'MY_CONTAINER_NAME'\n\n" 1>&2
    printf "Usage:\n\t$0 <container-name>\n\tMY_CONTAINER_NAME=<container-name> $0\n" 1>&2
    exit 1
  fi
fi

MY_STORAGE_ACCT=${MY_STORAGE_ACCT:-"$MY_CONTAINER_NAME"}
MY_RESOURCE_GROUP=${MY_RESOURCE_GROUP:="$MY_CONTAINER_NAME"}

## Only Delete if it exists
if az storage account list | jq '.[].name' -r | grep -q ${MY_STORAGE_ACCT}; then
  az storage container delete \
    --account-name ${MY_STORAGE_ACCT} \
    --name ${MY_CONTAINER_NAME} \
    --auth-mode login

  az storage account delete \
    --name ${MY_STORAGE_ACCT} \
    --resource-group ${MY_RESOURCE_GROUP} \
    --yes
fi

if az group list | jq '.[].name' -r | grep -q ${MY_RESOURCE_GROUP}; then
  az group delete --name=${MY_RESOURCE_GROUP} --yes
fi
