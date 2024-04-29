# AppRole using Dgraph

This is an example of using HashiCorp Vault AppRole with from the application Dgraph.

## Prerequisites

* [`docker`](https://docs.docker.com/engine/reference/commandline/cli/) and
* [`docker-compose`](https://docs.docker.com/compose/)
* [`vault`](https://www.vaultproject.io/)
* `curl`
* [`jq`](https://stedolan.github.io/jq/)
* POSIX Shell with either `zsh` or GNU `bash`
* GNU `grep`
* 

### Install Notes

**NOTE**: As `docker-compose` is now deprecated, Python environment and the `docker-compose` python module is no longer needed.

#### macOS (MacOS X)

You can easily install the tools using [Homebrew](https://brew.sh/): make any desired adjustments to [`Brewfile`](Brewfile), then run `brew bundle --verbose`.

#### Windows 11 Home

You can get the tools using [Chocolatey](https://chocolatey.org/): make any desired changes [`choco.config`](choco.config), and then run `choco install -y choco.config` to install [`docker`](https://docs.docker.com/docker-for-windows/install/), [vault](https://www.vaultproject.io/), and [msys2](https://www.msys2.org/) for command line environment for `bash`, `grep`, `jq`, and `curl` commands.  

Once [msys2](https://www.msys2.org/) is installed and setup, you can run the following to get `jq` and `curl`: `pacman -Syu && pacman -S jq curl`

## Part A: Launch Vault Server

```bash
## launch vault server
docker compose up --detach "vault"

# Choose source of scripts REST API or CLI
VAULT_SCRIPTS=./scripts/vault_cli
VAULT_SCRIPTS=./scripts/vault_api 

$VAULT_SCRIPTS/1.unseal.sh
```

## Part B: Setup Vault Server

```bash
$VAULT_SCRIPTS/2.configure.sh
$VAULT_SCRIPTS/3.policies.sh
$VAULT_SCRIPTS/4.roles.sh
```

## Part C: Create Secrets Using Admin Role

```bash
$VAULT_SCRIPTS/5.secrets_dgraph_create.sh
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
  | sed 's/^/* /'
```

## Part E: Testing Dgraph Services

```bash
export DGRAPH_ADMIN_USER="groot"
export DGRAPH_ADMIN_PSWD="password"
export DGRAPH_HTTP="localhost:8080"
DGRAPH_SCRIPTS=./scripts/dgraph

############################################
## ACL Feature
############################################
$DGRAPH_SCRIPTS/login.sh

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
