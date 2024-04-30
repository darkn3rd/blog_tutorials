# Vault REST API

These scripts demonstrate how to use AppRole using the vault REST API.

```bash
export VAULT_ADDR="http://localhost:8200"
./1.unseal.sh      # sets VAULT_ROOT_TOKEN 
./2.configure.sh

# Create Policies
./3.policies.sh
# Verify Policies
curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request GET \
  http://$VAULT_ADDR/v1/sys/policies/acl/admin | jq
curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request GET \
  http://$VAULT_ADDR/v1/sys/policies/acl/dgraph | jq

# Create Roles
./4.roles.sh
# Verify Roles
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request GET \
  http://$VAULT_ADDR/v1/auth/approle/role/admin | jq
curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request GET \
  http://$VAULT_ADDR/v1/auth/approle/role/dgraph | jq

# Create Secrets
export ENC_KEY=$(../randpasswd.sh)
export HMAC_SECRET=$(../randpasswd.sh)
./5.secrets_dgraph_create.sh
# Verify Secrets
./6.secrets_dgraph_read.sh
```
