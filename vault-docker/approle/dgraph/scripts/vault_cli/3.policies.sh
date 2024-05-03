#!/usr/bin/env bash
command -v vault > /dev/null || \
  { echo "[ERROR]: 'vault' command not not found" 1>&2; exit 1; }

[[ -z "$VAULT_ROOT_TOKEN" ]] && { echo 'VAULT_ROOT_TOKEN not specified. Aborting' 2>&1 ; exit 1; }
export VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
export VAULT_CONFIG_DIR=${VAULT_CONFIG_DIR:-"./vault"}
mkdir -p $VAULT_CONFIG_DIR

vault login $VAULT_ROOT_TOKEN

# Dgraph Policy
cat << EOF > $VAULT_CONFIG_DIR/policy_dgraph.hcl
path "secret/data/dgraph/*" {
  capabilities = [ "read", "update" ]
}
EOF

# Admin Policy
cat << EOF > $VAULT_CONFIG_DIR/policy_admin.hcl
# kv2 secret/dgraph/*
path "secret/data/dgraph/*" {
   capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "secret/metadata/dgraph/*" {
   capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Mount the AppRole auth method
path "sys/auth/approle" {
  capabilities = [ "create", "read", "update", "delete", "sudo" ]
}

# Configure the AppRole auth method
path "sys/auth/approle/*" {
  capabilities = [ "create", "read", "update", "delete" ]
}

# Create and manage roles
path "auth/approle/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Write ACL policies
path "sys/policies/acl/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
EOF

# Upload Policies
vault policy write admin $VAULT_CONFIG_DIR/policy_admin.hcl
vault policy write dgraph $VAULT_CONFIG_DIR/policy_dgraph.hcl

