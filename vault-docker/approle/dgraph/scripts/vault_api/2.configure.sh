#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || \
  { echo "[ERROR]: 'jq' command not not found" 1>&2; exit 1; }
[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}

# idempotent enable approle at approle/
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request GET \
  $VAULT_ADDR/v1/sys/auth \
  | jq -r '.data | to_entries | map(select(.value.type == "approle") | {key, value}).[].key' \
  | grep -q 'approle/' \
  || curl --silent \
       --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
       --request POST \
       --data '{"type": "approle"}' \
       $VAULT_ADDR/v1/sys/auth/approle

# idempotent enable kv-v2 at secrets/
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request GET \
  $VAULT_ADDR/v1/sys/mounts \
  | jq -r '.data | to_entries | map(select(.value.type == "kv") | {key, value}).[].key' \
  | grep -q 'secret/' \
  || curl --silent \
       --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
       --request POST \
       --data '{ "type": "kv-v2" }' \
       $VAULT_ADDR/v1/sys/mounts/secret
