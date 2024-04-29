#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export VAULT_ADDR=${VAULT_ADDR:"http://localhost:8200"}

export ENC_KEY=${ENC_KEY:-"12345678901234567890123456789012"}
export HMAC_SECRET=${HMAC_SECRET:-"12345678901234567890123456789012"}

##############
# login using admin role
############################
ROLE_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  http://$VAULT_ADDR/v1/auth/approle/role/admin/role-id \
    | jq -r '.data.role_id'
)

SECRET_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  http://$VAULT_ADDR/v1/auth/approle/role/admin/secret-id \
  | jq -r '.data.secret_id'
)

# generate token for admin role
VAULT_ADMIN_TOKEN=$(vault write auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID" \
  --format=json \
  | jq -r .auth.client_token
)

export VAULT_ADMIN_TOKEN=$(curl --silent \
  --request POST \
  --data \
"{
    \"role_id\": \"$VAULT_ADMIN_ROLE_ID\",
    \"secret_id\": \"$VAULT_ADMIN_SECRET_ID\"
}" \
  http://$VAULT_ADDR/v1/auth/approle/login \
  | jq -r '.auth.client_token'
)

##############
# write dgraph secrets using admin role
############################
cat << EOF > payload_alpha_secrets.json
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
  --data @./payload_alpha_secrets.json \
  http://$VAULT_ADDR/v1/secret/data/dgraph/alpha | jq

