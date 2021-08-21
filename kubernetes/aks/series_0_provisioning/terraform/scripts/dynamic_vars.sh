#!/usr/bin/env bash
AZ_SP_RESULTS=${AZ_SP_RESULTS:-"$(dirname $0)/../secrets.json"}

TF_VAR_client_secret=$(jq -r .password $AZ_SP_RESULTS)
TF_VAR_client_id=$(jq -r .appId $AZ_SP_RESULTS)
