#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
vault login $VAULT_ROOT_TOKEN

##############
# login using dgraph role
############################
ROLE_ID=$(vault read auth/approle/role/dgraph/role-id -format=json \
  | jq -r .data.role_id
)

SECRET_ID=$(vault write -f auth/approle/role/dgraph/secret-id -format=json \
  | jq -r .data.secret_id)

VAULT_DGRAPH_TOKEN=$(vault write auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID" \
  --format=json \
  | jq -r .auth.client_token
)

vault login $VAULT_DGRAPH_TOKEN

##############
# verify access to secrets using dgraph role
############################
vault kv get secret/dgraph/alpha

##############
# save credentials for Dgraph
############################
if [[ $? == 0 ]]; then
  echo $ROLE_ID > ./dgraph/vault_role_id
  echo $SECRET_ID > ./dgraph/vault_secret_id
fi