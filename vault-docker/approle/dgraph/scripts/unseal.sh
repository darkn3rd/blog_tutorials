#!/usr/bin/env bash
command -v grep > /dev/null || \
  { echo "[ERROR]: 'grep' command not not found" 1>&2; exit 1; }
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
export VAULT_CONFIG_DIR=${VAULT_CONFIG_DIR:-"./vault"}
mkdir -p $VAULT_CONFIG_DIR
echo $VAULT_CONFIG_DIR

# unseal
vault operator init | tee $VAULT_CONFIG_DIR/unseal.creds
for NUM in {1..3}; do
  vault operator unseal \
    $(grep -oP "(?<=Unseal Key $NUM: ).*" $VAULT_CONFIG_DIR/unseal.creds)
done
