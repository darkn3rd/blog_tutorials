#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

export VAULT_CONFIG_DIR=${VAULT_CONFIG_DIR:-"./vault"}
export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
[[ -f "$VAULT_CONFIG_DIR/.admin.token" ]] || { echo "'$VAULT_CONFIG_DIR/.admin.token' is not found. Aborting" 2>&1 ; exit 1; }
export VAULT_ADMIN_TOKEN=$(cat $VAULT_CONFIG_DIR/.admin.token)

##############
# login using dgraph role
############################
ROLE_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  $VAULT_ADDR/v1/auth/approle/role/dgraph/role-id \
    | jq -r '.data.role_id'
)

SECRET_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request POST \
  $VAULT_ADDR/v1/auth/approle/role/dgraph/secret-id \
    | jq -r '.data.secret_id'
)

export VAULT_DGRAPH_TOKEN=$(curl --silent \
  --request POST \
  --data "{ \"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\" }" \
  $VAULT_ADDR/v1/auth/approle/login \
    | jq -r '.auth.client_token'
)

##############
# verify access to secrets using dgraph role
############################
curl --silent \
  --header "X-Vault-Token: $VAULT_DGRAPH_TOKEN" \
  --request GET \
  $VAULT_ADDR/v1/secret/data/dgraph/alpha | jq


##############
# save credentials for Dgraph
############################
if [[ $? == 0 ]]; then
  echo $ROLE_ID > ./dgraph/vault_role_id
  echo $SECRET_ID > ./dgraph/vault_secret_id
fi