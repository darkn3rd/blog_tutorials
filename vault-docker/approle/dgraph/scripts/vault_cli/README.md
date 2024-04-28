# Vault CLI

These scripts demonstrate how to use AppRole using the vault cli.

```bash
export VAULT_ADDR="http://localhost:8200"
./1.unseal.sh      # sets VAULT_ROOT_TOKEN 
./2.configure.sh
./3.policies.sh
./4.roles.sh
# secrets
export ENC_KEY=$(../randpasswd.sh)
export HMAC_SECRET=$(../randpasswd.sh)
./5.secrets_dgraph_create.sh
# Verify 
./6.secrets_dgraph_read.sh
```