#!/usr/bin/env bash

## Verify required commands
command -v az > /dev/null || \
  { echo "[ERROR]: 'az' command not not found" 1>&2; exit 1; }

export AZ_SUBSCRIPTION_ID=$(az account show --query id | tr -d '"')

AZ_SP_RESULTS=${AZ_SP_RESULTS:-"$(dirname $0)/../secrets.json"}


az ad sp create-for-rbac \
  --name "${AZ_SP_NAME:-"aks-basic-test"}"
  --role="Contributor"
  --scopes="/subscriptions/$AZ_SUBSCRIPTION_ID" > $AZ_SP_RESULTS
