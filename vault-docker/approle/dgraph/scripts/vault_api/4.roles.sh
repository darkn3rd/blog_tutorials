#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}

vault login $VAULT_ROOT_TOKEN

##############
# create admin role
############################
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  --data \
'{
    "token_policies": "admin",
    "token_ttl": "1h",
    "token_max_ttl": "4h"
}' \
  $VAULT_ADDR/v1/auth/approle/role/admin


##############
# create dgraph role
############################
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  --data \
'{
    "token_policies": "dgraph",
    "token_ttl": "1h",
    "token_max_ttl": "4h"
}' \
  $VAULT_ADDR/v1/auth/approle/role/dgraph
