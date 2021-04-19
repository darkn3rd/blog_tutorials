# AppRole using Dgraph

This is an example of using HashiCorp Vault AppRole with from the application Dgraph.

## Prerequisites

* [`docker`](https://docs.docker.com/engine/reference/commandline/cli/)
* [`docker-compose`](https://docs.docker.com/compose/)
* `curl`
* [`jq`](https://stedolan.github.io/jq/)
* `bash`
* GNU `grep`
* GNU `sed`

### MacOS

You can easily install the tools with [Homebrew](https://brew.sh/). make any desired adjustments to [`Brewfile`](Brewvile), then run `brew bundle --verbose`.

For `docker-compose` in particular, I recommend installing this through `pip` and using a virtualenv for this.  This can be setup with [`pyenv`](https://github.com/pyenv/pyenv) (`brew install pyenv pyenv-virtualenv`).

For other bottles or cask, you can get further instructions with `brew info`, e.g. `brew info gnu-sed`.

### Windows 10

If you have [Chocolatey](https://chocolatey.org/), you run `choco install -y choco.config` to install [`docker`](https://docs.docker.com/docker-for-windows/install/), [`docker-compose`](https://docs.docker.com/compose/), and [msys2](https://www.msys2.org/) for command line environment (bash, gnu sed, gnu grep, jq, curl).

Once [msys2](https://www.msys2.org/) is installed and setup, you can run the following to get `jq` and `curl`: `pacman -Syu && pacman -S jq curl`

## Docker Compose using Pyenv

If `pyenv` and `pyenv-virtualenv`, are installed, you can created a virtualenv using this:


```bash
PYTHON_VERSION="3.9.4" # choose desired python version
pyenv virtualenv $PYTHON_VERSION docker-compose-$PYTHON_VERSION
pyenv shell docker-compose-$PYTHON_VERSION
pip install --upgrade pip
pip install docker-compose
```


## Part A: Configure Vault Server

```bash
## launch vault server
docker-compose up --detach "vault"

## initialize vault and copy secrets down
docker exec -t vault vault operator init

## unseal vault using copied secrets
docker exec -ti vault vault operator unseal
docker exec -ti vault vault operator unseal
docker exec -ti vault vault operator unseal

# export results
export VAULT_ROOT_TOKEN="<root-token>"
export VAULT_ADDRESS="127.0.0.1:8200"
```


## Part B: Setup using Root Token

```bash
############################################
## Enabled Features: AppRole, KV Secrets v2
############################################curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  --data '{"type": "approle"}' \
  $VAULT_ADDRESS/v1/sys/auth/approle

curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  --data '{ "type": "kv-v2" }' \
  $VAULT_ADDRESS/v1/sys/mounts/secret

############################################
## Admin Policy
############################################
cat <<EOF > ./vault/policy_admin.json
{
  "policy": "$(sed -e ':a;N;$!ba;s/\n/\\n/g' \
                   -e 's/"/\\"/g' \
                   vault/policy_admin.hcl)"
}
EOF

curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request PUT --data @./vault/policy_admin.json \
  http://$VAULT_ADDRESS/v1/sys/policies/acl/admin

## verify the policy
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request GET \
  http://$VAULT_ADDRESS/v1/sys/policies/acl/admin | jq


############################################
## Admin Role
############################################
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  --data '{
    "token_policies": "admin",
    "token_ttl": "1h",
    "token_max_ttl": "4h"
}' \
  http://$VAULT_ADDRESS/v1/auth/approle/role/admin

## verify the role
curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request GET \
  http://$VAULT_ADDRESS/v1/auth/approle/role/admin | jq

############################################
## Retrieve Admin token
############################################
VAULT_ADMIN_ROLE_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  http://$VAULT_ADDRESS/v1/auth/approle/role/admin/role-id \
    | jq -r '.data.role_id'
)

VAULT_ADMIN_SECRET_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  --request POST \
  http://$VAULT_ADDRESS/v1/auth/approle/role/admin/secret-id \
    | jq -r '.data.secret_id'
)

export VAULT_ADMIN_TOKEN=$(curl --silent \
  --request POST \
  --data "{ \"role_id\": \"$VAULT_ADMIN_ROLE_ID\", \"secret_id\": \"$VAULT_ADMIN_SECRET_ID\" }" \
  http://$VAULT_ADDRESS/v1/auth/approle/login \
    | jq -r '.auth.client_token'
)
```

## Part C: Setup using Admin Token

```bash
curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request POST \
  --data @./vault/payload_alpha_secrets.json \
  http://$VAULT_ADDRESS/v1/secret/data/dgraph/alpha | jq



############################################
## Dgraph Policy
############################################
cat <<EOF > ./vault/policy_dgraph.json
{
  "policy": "$(sed -e ':a;N;$!ba;s/\n/\\n/g' \
                   -e 's/"/\\"/g' \
                   vault/policy_dgraph.hcl)"
}
EOF

## create the dgraph policy
curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request PUT --data @./vault/policy_dgraph.json \
  http://$VAULT_ADDRESS/v1/sys/policies/acl/dgraph

## verify the policy
curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request GET \
  http://$VAULT_ADDRESS/v1/sys/policies/acl/dgraph | jq

############################################
## Dgraph Role
############################################
curl --silent \
 --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
 --request POST \
 --data '{
    "token_policies": "dgraph",
    "token_ttl": "1h",
    "token_max_ttl": "4h"
}' \
 http://$VAULT_ADDRESS/v1/auth/approle/role/dgraph

curl --silent \
 --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
 --request GET \
 http://$VAULT_ADDRESS/v1/auth/approle/role/dgraph | jq

############################################
## Retrieve Dgraph token
############################################
VAULT_DGRAPH_ROLE_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  http://$VAULT_ADDRESS/v1/auth/approle/role/dgraph/role-id \
    | jq -r '.data.role_id'
)

VAULT_DGRAPH_SECRET_ID=$(curl --silent \
  --header "X-Vault-Token: $VAULT_ADMIN_TOKEN" \
  --request POST \
  http://$VAULT_ADDRESS/v1/auth/approle/role/dgraph/secret-id \
    | jq -r '.data.secret_id'
)

export VAULT_DGRAPH_TOKEN=$(curl --silent \
  --request POST \
  --data "{ \"role_id\": \"$VAULT_DGRAPH_ROLE_ID\", \"secret_id\": \"$VAULT_DGRAPH_SECRET_ID\" }" \
  http://$VAULT_ADDRESS/v1/auth/approle/login \
    | jq -r '.auth.client_token'
)

############################################
## Save Role-Id and Secret-ID for Dgraph
############################################
echo $VAULT_DGRAPH_ROLE_ID > ./dgraph/vault_role_id
echo $VAULT_DGRAPH_SECRET_ID > ./dgraph/vault_secret_id
```

## Part C: Verify using Dgraph Token

```bash
curl --silent \
  --header "X-Vault-Token: $VAULT_DGRAPH_TOKEN" \
  --request GET \
  http://$VAULT_ADDRESS/v1/secret/data/dgraph/alpha | jq
```

## Part D: Start Dgraph Service

```bash
## Start Dgraph Zero and Dgraph Alpha
docker-compose up --detach

## check logs for "Server is ready"
docker logs alpha1

# print a list of features enabled
export DGRAPH_ALPHA_ADDRESS="localhost:8080"
curl --silent http://$DGRAPH_ALPHA_ADDRESS/health \
  | jq -r '.[].ee_features | .[]' \
  | sed 's/^/* /'
```

## Part E: Testing Dgraph Services

```bash
DGRAPH_ADMIN_USER="groot"
DGRAPH_ADMIN_PSWD="password"
export DGRAPH_ALPHA_ADDRESS="localhost:8080"


############################################
## ACL Feature
############################################
export DGRAPH_ACCESS_TOKEN=$(curl --silent \
  --request POST \
  --data "{
    \"userid\": \"$DGRAPH_ADMIN_USER\",
    \"password\": \"$DGRAPH_ADMIN_PSWD\",
    \"namespace\": 0
}" \
  http://$DGRAPH_ALPHA_ADDRESS/login \
    | grep -oP '(?<=accessJWT":")[^"]*'
)


############################################
## Export Feature w/ Encryption + ACL Login
############################################
curl --silent \
  --header "Content-Type: application/graphql" \
  --header "X-Dgraph-AccessToken: $DGRAPH_ACCESS_TOKEN" \
  --request POST \
  --upload-file ./dgraph/export.graphql \
  http://$DGRAPH_ALPHA_ADDRESS/admin | jq

## Verify
## NOTE: results should be 'data', not 'gzip compressed data'
find ./dgraph/export/ -name '*.gz' | xargs -n 1 file


############################################
## Backup Feature w/ Encryption + ACL Login
############################################
curl --silent \
  --header "Content-Type: application/graphql" \
  --header "X-Dgraph-AccessToken: $DGRAPH_ACCESS_TOKEN" \
  --request POST \
  --upload-file ./dgraph/backup.graphql \
  http://$DGRAPH_ALPHA_ADDRESS/admin | jq

## Verify
## NOTE: results should be 'data', not 'snappy framed data'
find ./dgraph/backups/ -name '*.backup' | xargs -n 1 file  
```
