#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }

vault login $VAULT_ROOT_TOKEN

export ENC_KEY=${ENC_KEY:-"12345678901234567890123456789012"}
export HMAC_SECRET=${HMAC_SECRET:-"12345678901234567890123456789012"}

##############
# login using admin role
############################
ROLE_ID=$(vault read auth/approle/role/admin/role-id -format=json \
  | jq -r .data.role_id
)

SECRET_ID=$(vault write -f auth/approle/role/admin/secret-id -format=json \
  | jq -r .data.secret_id)

# generate token for admin role
VAULT_ADMIN_TOKEN=$(vault write auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID" \
  --format=json \
  | jq -r .auth.client_token
)

# login using admin token
vault login $VAULT_ADMIN_TOKEN

##############
# write dgraph secrets using admin role
############################
vault kv put secret/dgraph/alpha \
  enc_key="$ENC_KEY" \
  hmac_secret_file="$HMAC_SECRET"


