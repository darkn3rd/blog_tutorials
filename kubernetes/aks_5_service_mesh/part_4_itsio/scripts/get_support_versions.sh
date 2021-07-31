#!/usr/bin/env bash

## Verify required commands
command -v az > /dev/null || \
  { echo "[ERROR]: 'az' command not not found" 1>&2; exit 1; }
  [[ -z "$AZ_LOCATION" ]] && { echo 'AZ_LOCATION not specified. Aborting' 2>&1 ; exit 1; }



az aks get-versions --location ${AZ_LOCATION} --query "orchestrators[].orchestratorVersion"
