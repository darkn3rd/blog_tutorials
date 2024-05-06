#!/usr/bin/env bash
grep --version | grep -q GNU  || \
  { echo "[ERROR]: GNU grep command not not found" 1>&2; exit 1; }
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
export VAULT_CONFIG_DIR=${VAULT_CONFIG_DIR:-"./vault"}
mkdir -p $VAULT_CONFIG_DIR

# initialize
vault operator init | tee $VAULT_CONFIG_DIR/unseal.creds

# unseal
NUM=1 
until [[ "$SEALED" == "false" ]]; do
  SEALED=$(
    vault operator unseal \
        $(grep -oP "(?<=Unseal Key $NUM: ).*" $VAULT_CONFIG_DIR/unseal.creds) \
      | awk '/Sealed/{ print $2 }'
  )
  let NUM="$NUM + 1" 
done
