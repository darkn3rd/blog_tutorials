#!/usr/bin/env bash
command -v grep > /dev/null || \
  { echo "[ERROR]: 'grep' command not not found" 1>&2; exit 1; }
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}

## unseal
vault operator init | tee unseal.creds
for NUM in {1..3}; do
  vault operator unseal \
    $(grep -oP "(?<=Unseal Key $NUM: ).*" unseal.creds)
done

# export the results for use in other steps
export VAULT_ROOT_TOKEN="$(
  grep -oP "(?<=Initial Root Token: ).*" unseal.creds
)"