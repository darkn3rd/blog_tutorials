# Vault CLI

These scripts demonstrate how to use AppRole using the vault cli.

```bash
export VAULT_ADDR="http://localhost:8200"
./1.unseal.sh      # sets VAULT_ROOT_TOKEN 
./2.configure.sh

# Create Policies
./3.policies.sh
# Verify Policies
vault policy read admin
vault policy read dgraph

# Create Roles
./4.roles.sh
# Verify Roles
vault read auth/approle/role/admin
vault read auth/approle/role/dgraph

# Create Secrets
export ENC_KEY=$(../randpasswd.sh)
export HMAC_SECRET=$(../randpasswd.sh)
./5.secrets_dgraph_create.sh
# Verify Secrets
./6.secrets_dgraph_read.sh

# Save Secrets into Dgraph Config
echo $DGRAPH_ROLE_ID > ./dgraph/vault_role_id
echo $DGRAPH_SECRET_ID > ./dgraph/vault_secret_id
```