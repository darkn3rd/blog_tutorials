#!/usr/bin/env bash

## Verify required commands
command -v az > /dev/null || \
  { echo "[ERROR]: 'az' command not not found" 1>&2; exit 1; }

az provider list \
 --query "[?namespace=='Microsoft.ContainerService'].resourceTypes[] | [?resourceType=='managedClusters'].locations[]" \
 -o tsv
