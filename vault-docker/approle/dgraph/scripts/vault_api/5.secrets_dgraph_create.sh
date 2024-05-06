#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }
command -v jq > /dev/null || \
  { echo "[ERROR]: 'jq' command not not found" 1>&2; exit 1; }
[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}

export ENC_KEY=${ENC_KEY:-"12345678901234567890123456789012"}
export HMAC_SECRET=${HMAC_SECRET:-"12345678901234567890123456789012"}

export VAULT_CONFIG_DIR=${VAULT_CONFIG_DIR:-"./vault"}
mkdir -p $VAULT_CONFIG_DIR

##############
# login using admin role
############################
ROLE_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  $VAULT_ADDR/v1/auth/approle/role/admin/role-id \
    | jq -r '.data.role_id'
)

SECRET_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  $VAULT_ADDR/v1/auth/approle/role/admin/secret-id \
  | jq -r '.data.secret_id'
)

# generate token for admin role
export VAULT_ADMIN_TOKEN=$(curl --silent \
  --request POST \
  --data \
"{
    \"role_id\": \"$ROLE_ID\",
    \"secret_id\": \"$SECRET_ID\"
}" \
  $VAULT_ADDR/v1/auth/approle/login \
  | jq -r '.auth.client_token'
)

if ! [[ -z $VAULT_ADMIN_TOKEN ]]; then
  echo ${VAULT_ADMIN_TOKEN} > $VAULT_CONFIG_DIR/.admin.token
fi

##############
# write dgraph secrets using admin role
############################
cat << EOF > $VAULT_CONFIG_DIR/payload_alpha_secrets.json
{
  "options": {
    "cas": 0
  },
  "data": {
    "enc_key": "$ENC_KEY",
    "hmac_secret_file": "$HMAC_SECRET"
  }
}
EOF

curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request POST \
  --data @$VAULT_CONFIG_DIR/payload_alpha_secrets.json \
  $VAULT_ADDR/v1/secret/data/dgraph/alpha | jq

