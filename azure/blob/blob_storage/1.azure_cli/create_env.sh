#!/usr/bin/env bash

command -v az > /dev/null || \
  { echo "'az' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || \
  { echo "'jq' command not not found" 1>&2; exit 1; }
[[ -z "$MY_STORAGE_ACCT" ]] && \
  { echo "'MY_STORAGE_ACCT' env var must be defined" 1>&2; exit 1; }
[[ -z "$MY_RESOURCE_GROUP" ]] && \
  { echo "'MY_RESOURCE_GROUP' env var must be defined" 1>&2; exit 1; }

# GET CONTAINER NAME CONNECTION STRING
CONN_STR=$(az storage account show-connection-string \
    --name "${MY_STORAGE_ACCT}" \
    --resource-group "${MY_RESOURCE_GROUP}" \
     | jq .connectionString -r
)

MINIO_SECRET_KEY=$(grep -oP '(?<=AccountKey=).*' <<< $CONN_STR)
MINIO_ACCESS_KEY=$(grep -oP '(?<=AccountName=)[^;]*' <<< $CONN_STR)

cat <<-ENVEOF > .env
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
ENVEOF
