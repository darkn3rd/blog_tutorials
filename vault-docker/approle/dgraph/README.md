# AppRole using Dgraph

This is an example of using [HashiCorp Vault AppRole](https://www.vaultproject.io/) with from the application Dgraph.  This content is related to blogs written here:

* [Vault AppRole Auth: The Hard Way: Securely Storing Secrets using HashiCorp Vault REST API](https://medium.com/@joachim8675309/vault-approle-auth-the-hard-way-0a24a208a252)
* [Vault AppRole Auth: The Easy Way: Securely Storing Secrets with HashiCorp Vault](https://joachim8675309.medium.com/vault-approle-auth-the-easy-way-15b4861810c7)

## Required Tools

* Container Platform
   * [`docker`](https://docs.docker.com/engine/reference/commandline/cli/) with the [Compose](https://docs.docker.com/compose/) plugin. Linux can run the the [Docker Engine](https://docs.docker.com/engine/install/), but macOS and Windows need to use a virtual machine that runs Linux, such as [Docker Desktop](https://docs.docker.com/desktop/).
      * [Docker Desktop](https://docs.docker.com/desktop/) (Windows or macOS) is a docker environment that manages a virtual machine running Linux (Hyper/V or WSL on Windows, and Hypervisor Framework on macOS)
      * [Docker Engine](https://docs.docker.com/engine/install/) (Linux) is the docker engine, no virtualization is needed when running on Linux. 
* Client CLI Tools
    * [`vault`](https://www.vaultproject.io/) - client used to interact with a Vault server
    * [`curl`](https://curl.se/) - required to interact with REST API or GraphQL API
    * [`jq`](https://stedolan.github.io/jq/) - required to work with JSON from the shell
* POSIX Shell Environment
    * [`zsh`](https://www.zsh.org/) or 
    * [GNU `bash`](https://www.gnu.org/software/bash/)
* GNU Tools
    * [GNU `grep`](https://www.gnu.org/software/grep/) - required matching with PCRE 
    * [GNU `sed`](https://www.gnu.org/software/sed/) - required for Vault with REST API

## Optional Tools

* [`bat`](https://github.com/sharkdp/bat) - useful for color syntax-highlighting of Vault policies (HCL)

### Install Notes

Below are some notes to get started quickly. 

**NOTE**: As `docker-compose` is now deprecated, Python environment and the `docker-compose` python module is no longer needed.  Instructions for this have been removed. 

#### macOS (aka MacOS X)

You can easily install the tools using [Homebrew](https://brew.sh/): make any desired adjustments to [`Brewfile`](Brewfile), then run `brew bundle --verbose`.

#### Windows 11 Home

You can get the tools using [Chocolatey](https://chocolatey.org/): make any desired changes [`choco.config`](choco.config), and then run `choco install -y choco.config` to install [`docker`](https://docs.docker.com/docker-for-windows/install/), [vault](https://www.vaultproject.io/), and [msys2](https://www.msys2.org/) for command line environment for `bash`, `grep`, `jq`, and `curl` commands.  

Once [msys2](https://www.msys2.org/) is installed and setup, you can run the following to get `jq` and `curl`: `pacman -Syu && pacman -S jq curl`

## Overview

You can choose whether to use RESTful API or use the Vault CLI.  Follow Part1A or Part1B depending on your preference. 

A summary of the steps below are:

1. Launch, Unseal, Login to Vault
2. Configure Vault: Enable AppRole and KV (ver 2)
3. Setup Policies: `dgraph` and `admin` policies
4. Setup Roles: `dgraph` and `admin` roles
5. Create Secrets: using `admin` role, create secrets
6. Read Secrets: using `dgraph` role to test access to the secrets

After this, we can test out an example application Dgraph:

1. Launch Dgraph
2. Login to Dgraph 
3. (optional) Getting Started tutorial to upload data and schema
4. Test an Export operation
5. Test a Backup operation

### Part 1: Launch and Unseal Vault

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

# Unseal vault
./scripts/unseal.sh
export VAULT_ROOT_TOKEN="$(
  grep -oP "(?<=Initial Root Token: ).*" $VAULT_CONFIG_DIR/unseal.creds
)"
export VAULT_ADDR="http://localhost:8200"
```

From this point, chose whether you wish to use the Vault REST API using `curl` or using the `vault` CLI to interact with the Vault server.

### Part 1A: Vault API

```bash
export VAULT_SCRIPTS=./scripts/vault_api

#######
# Enable Auth and KVv2
################
$VAULT_SCRIPTS/2.configure.sh
# verify auth enabled at approle/
curl --silent --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  $VAULT_ADDR/v1/sys/auth | jq -r '.data'
# verify kv-v2 enabled at secret/
curl --silent --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  $VAULT_ADDR/v1/sys/mounts | jq -r '.data'

#######
# Setup Policies
################
$VAULT_SCRIPTS/3.policies.sh
# verify  policies
BAT_CMD=$(command -v bat > /dev/null && echo "$(command -v bat) --language hcl")
curl --silent --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  $VAULT_ADDR/v1/sys/policies/acl/admin | jq .data.policy \
  | sed -r -e 's/\\n/\n/g' -e 's/\\"/"/g' -e 's/^"(.*)"$/\1/' \
  | $BAT_CMD
curl --silent --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  $VAULT_ADDR/v1/sys/policies/acl/dgraph | jq .data.policy \
  | sed -r -e 's/\\n/\n/g' -e 's/\\"/"/g' -e 's/^"(.*)"$/\1/' \
  | $BAT_CMD

#######
# Setup Roles
################
$VAULT_SCRIPTS/4.roles.sh
# verify roles
curl --silent --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  $VAULT_ADDR/v1/auth/approle/role/admin | jq .data
curl --silent --header "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  $VAULT_ADDR/v1/auth/approle/role/dgraph | jq .data

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

### Part 1B: Vault CLI

```bash
export VAULT_SCRIPTS=./scripts/vault_cli

#######
# Enable Auth and KVv2
################
$VAULT_SCRIPTS/2.configure.sh
vault login $VAULT_ROOT_TOKEN
# verify auth enabled at approle/
vault auth list
# verify kv-v2 enabled at secret/
vault secrets list

#######
# Setup Policies
################
$VAULT_SCRIPTS/3.policies.sh
# verify  policies
BAT_CMD=$(command -v bat > /dev/null && echo "$(command -v bat) --language hcl")
vault policy read admin | $BAT_CMD
vault policy read dgraph | $BAT_CMD

#######
# Setup Roles
################
$VAULT_SCRIPTS/4.roles.sh
# verify roles
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

### Part 2: Dgraph

```bash
export DGRAPH_CONFIG_DIR=$TEMP_DIR/dgraph
mkdir -p $DGRAPH_CONFIG_DIR

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

############################################
## ACL Feature - login operation
############################################
export DGRAPH_ADMIN_USER="groot"
export DGRAPH_ADMIN_PSWD="password"
export DGRAPH_HTTP="localhost:8080"
DGRAPH_SCRIPTS=./scripts/dgraph
$DGRAPH_SCRIPTS/login.sh
export DGRAPH_TOKEN=$(cat $DGRAPH_CONFIG_DIR/.dgraph.token)

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
docker compose stop && docker compose rm --force
PATHS=(
  ./vault/data/*
  ./dgraph/{backups,export}/*
  ./dgraph/*_id
  $TEMP_DIR
)
for P in ${PATHS[@]}; do rm -rf $P; done

unset VAULT_ROOT_TOKEN VAULT_ADDR VAULT_SCRIPTS VAULT_CONFIG_DIR TEMP_DIR \
  DGRAPH_HTTP DGRAPH_CONFIG_DIR ENC_KEY HMAC_SECRET DGRAPH_ADMIN_USER DGRAPH_ADMIN_PSWD DGRAPH_TOKEN
```


## Tested Environments

These are the environments that were tested on April, 2024.

### macOS Monterey 12.6.3 build 21G419
--------------------------------------------------
* **Docker Desktop for macOS** 4.29.0
  * **Docker Engine** 26.0.0
    * Plugin: **Compose** v2.26.1
* **zsh** 5.9 (arm-apple-darwin21.3.0)
* **GNU bash**, version 5.2.21(1)-release (aarch64-apple-darwin21.6.0)
* grep (**GNU grep**) 3.11
* sed (**GNU sed**) 4.9
* **jq** 1.7.1
* **Vault** v1.16.2

Windows 11 Home [WinNT 10.0.22631.34467] with MSYS
--------------------------------------------------
* **Docker Desktop for Windows** 4.29.0
  * **Docker Engine** 26.0.0
    * Plugin: **Compose**: v2.26.1
* MSYS
  * **zsh** 5.9 (x86_64-pc-msys)
  * **GNU bash**, version 5.2.26(1)-release (x86_64-pc-msys)
  * grep (**GNU grep**) 3.0
  * sed (**GNU sed**) 4.9
  * **jq** 1.7.1
* **Vault** v1.16.1

Pop!_OS 22.04 LTS (Ubuntu Jammy)
--------------------------------------------------
* **Docker Engine** version 26.1.0, build 9714adc
  * Plugin: **Compose** version v2.26.1
* **zsh** 5.8.1 (x86_64-ubuntu-linux-gnu)
* **GNU bash**, version 5.1.16(1)-release (x86_64-pc-linux-gnu)
* grep (**GNU grep**) 3.7
* sed (**GNU sed**) 4.8                                 
* **jq** 1.6
* **Vault** v1.16.2

