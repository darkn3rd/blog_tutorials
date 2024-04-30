# AppRole using Dgraph

This is an example of using HashiCorp Vault AppRole with from the application Dgraph.

## Prerequisites

* [`docker`](https://docs.docker.com/engine/reference/commandline/cli/) with the [Compose](https://docs.docker.com/compose/) plugin. 
  * [Docker Desktop](https://docs.docker.com/desktop/) (Windows or macOS) is a docker environment that manages a virtual machine running Linux (Hyper/V or WSL on Windows, and Hypervisor Framework on macOS)
  * [Docker Engine](https://docs.docker.com/engine/install/) (Linux) is the docker engine, no virtualization is needed when running on Linux. 
* [`vault`](https://www.vaultproject.io/) - client used to interact with a Vault server
* [`curl`](https://curl.se/) - required to interact with REST API or GraphQL API
* [`jq`](https://stedolan.github.io/jq/) - required to work with JSON from the shell
* POSIX Shell
    * [`zsh`](https://www.zsh.org/) or 
    * [GNU `bash`](https://www.gnu.org/software/bash/)
* [GNU `grep`](https://www.gnu.org/software/grep/) - required matching with PCRE 
* [GNU `sed`](https://www.gnu.org/software/sed/) - required for Vault with REST API

### Install Notes

Below are some notes to get started quickly. 

**NOTE**: As `docker-compose` is now deprecated, Python environment and the `docker-compose` python module is no longer needed.

#### macOS (aka MacOS X)

You can easily install the tools using [Homebrew](https://brew.sh/): make any desired adjustments to [`Brewfile`](Brewfile), then run `brew bundle --verbose`.

#### Windows 11 Home

You can get the tools using [Chocolatey](https://chocolatey.org/): make any desired changes [`choco.config`](choco.config), and then run `choco install -y choco.config` to install [`docker`](https://docs.docker.com/docker-for-windows/install/), [vault](https://www.vaultproject.io/), and [msys2](https://www.msys2.org/) for command line environment for `bash`, `grep`, `jq`, and `curl` commands.  

Once [msys2](https://www.msys2.org/) is installed and setup, you can run the following to get `jq` and `curl`: `pacman -Syu && pacman -S jq curl`

## Part 1: Setup Vault

After the Docker environment is running and the necessary client tools are installed, we can launch the Vault server and unseal it. 

```bash
#######
# Setup Vault
################
export TEMP_DIR=$(mktemp -d)
echo "INFO: Using '$TEMP_DIR' for staging"
export VAULT_CONFIG_DIR=$TEMP_DIR/vault
mkdir -p $VAULT_CONFIG_DIR

# Launch Vault
docker compose up --detach "vault"
VAULT_SCRIPTS=./scripts/vault_api

# Unseal vault
$VAULT_SCRIPTS/1.unseal.sh
export VAULT_ROOT_TOKEN="$(
  grep -oP "(?<=Initial Root Token: ).*" $VAULT_CONFIG_DIR/unseal.creds
)"
export VAULT_ADDR="http://localhost:8200"
```

From here, you can choose whether to use RESTful API or use the Vault CLI.  Follow Part1A or Part1B depending on your preference. 

A summary of the steps below are:

1. Launch, Unseal, Login to Vault
2. Configure Vault: Enable AppRole and KV (ver 2)
3. Setup Policies: `dgraph` and `admin` policies
4. Setup Roles: `dgraph` and `admin` roles
5. Create Secrets: using `admin` role, create secrets
6. Read Secrets: using `dgraph` role to test access to the secrets

After this, we can test out an example application

1. Launch Dgraph
2. Login to Dgraph 
3. (optional) Getting Started tutorial to upload data and schema
4. Test an Export operation
5. Test a Backup operation


## Part 1A: Vault Managed through RESTful API

```bash
#######
# Enable Auth and KVv2
################
$VAULT_SCRIPTS/2.configure.sh

#######
# Setup Policies
################
$VAULT_SCRIPTS/3.policies.sh

#######
# Setup Roles
################
$VAULT_SCRIPTS/4.roles.sh

#######
# Creates Secrets
################
export ENC_KEY=$(./scripts/randpasswd.sh)
export HMAC_SECRET=$(./scripts/randpasswd.sh)
$VAULT_SCRIPTS/5.secrets_dgraph_create.sh

#######
# Test Secrets
################
$VAULT_SCRIPTS/6.secrets_dgraph_read.sh
```

## Part 1B: Vault Managed through Vault CLI

```bash
#######
# Enable Auth and KVv2
################
$VAULT_SCRIPTS/2.configure.sh
vault login $VAULT_ROOT_TOKEN
vault auth list
vault secrets list

#######
# Setup Policies
################
$VAULT_SCRIPTS/3.policies.sh
vault policy read admin
vault policy read dgraph

#######
# Setup Roles
################
$VAULT_SCRIPTS/4.roles.sh
vault read auth/approle/role/admin
vault read auth/approle/role/dgraph

#######
# Creates Secrets
################
export ENC_KEY=$(./scripts/randpasswd.sh)
export HMAC_SECRET=$(./scripts/randpasswd.sh)
$VAULT_SCRIPTS/5.secrets_dgraph_create.sh

#######
# Test Secrets
################
$VAULT_SCRIPTS/6.secrets_dgraph_read.sh
```


## Part D: Start Dgraph Service

```bash
## Start Dgraph Zero and Dgraph Alpha
docker compose up --detach "zero1"
if [[ -f "./dgraph/vault_role_id" && -f "./dgraph/vault_secret_id" ]]; then
  docker compose up --detach "alpha1"
fi

## check logs for "Server is ready"
docker logs alpha1

## highlight
docker logs alpha1 2>&1 | grep --color -E 'ACL secret key|Encryption feature|$'

# print a list of features enabled
export DGRAPH_HTTP="localhost:8080"
curl --silent http://$DGRAPH_HTTP/health \
  | jq -r '.[].ee_features | .[]' \
  | sed 's/^/* /' \
  | grep --color --extended-regexp 'acl|encrypt.*|$'
```

## Part E: Testing vvvDgraph Services

```bash
export DGRAPH_ADMIN_USER="groot"
export DGRAPH_ADMIN_PSWD="password"
export DGRAPH_HTTP="localhost:8080"
DGRAPH_SCRIPTS=./scripts/dgraph
export DGRAPH_TOKEN=$(cat .dgraph.token)
############################################
## ACL Feature
############################################
$DGRAPH_SCRIPTS/login.sh

############################################
## Getting Started (optional)
############################################
$DGRAPH_SCRIPTS/getting_started/1.data_json.sh
$DGRAPH_SCRIPTS/getting_started/2.schema.sh
$DGRAPH_SCRIPTS/getting_started/3.query_starring_edge.sh
$DGRAPH_SCRIPTS/getting_started/4.query_movies_after_1980.sh

############################################
## Export Feature w/ Encryption + ACL Login
############################################
$DGRAPH_SCRIPTS/export.sh
## Verify
## NOTE: results should be 'data', not 'gzip compressed data'
find ./dgraph/export/ -name '*.gz' | xargs -n 1 file

############################################
## Backup Feature w/ Encryption + ACL Login
############################################
$DGRAPH_SCRIPTS/backup.sh

## Verify
## NOTE: results should be 'data', not 'snappy framed data'
find ./dgraph/backups/ -name '*.backup' | xargs -n 1 file  
```

## Cleanup

```bash
# Remove resources used in compose environment
docker compose stop && docker compose rm
rm -rf ./vault/data/*
rm $TEMP_DIR/vault/*
```