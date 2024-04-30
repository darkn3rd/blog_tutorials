#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}

vault login $VAULT_ROOT_TOKEN

# idempotent enable approle at approle/
vault auth list | grep -q '^approle' || vault auth enable approle

# idempotent enable kv-v2 at secrets/
vault secrets list | grep -q '^secret' || vault secrets enable -path=secret kv-v2

