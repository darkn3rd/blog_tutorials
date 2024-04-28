#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }

vault login $VAULT_ROOT_TOKEN


##############
# create admin role
############################
vault write auth/approle/role/admin \
  policies="admin" \
  token_ttl="1h" \
  token_max_ttl="4h"

##############
# create dgraph role
############################
vault write auth/approle/role/dgraph \
  policies="dgraph" \
  token_ttl="1h" \
  token_max_ttl="4h"
