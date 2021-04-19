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

For `docker-compose` in particular, I recommend installing this through `pip` and using a virtualenv for this.  This can be setup with [`pyenv`](https://github.com/pyenv/pyenv) (`brew install pyenv`).

For other bottles or cask, you can get further instructions with `brew info`, e.g. `brew info gnu-sed`.

### Windows 10

If you have [Chocolatey](https://chocolatey.org/), you run `choco install -y choco.config` to install [`docker`](https://docs.docker.com/docker-for-windows/install/), [`docker-compose`](https://docs.docker.com/compose/), and [msys2](https://www.msys2.org/) for command line environment (bash, gnu sed, gnu grep, jq, curl).

Once [msys2](https://www.msys2.org/) is installed and setup, you can run the following to get `jq` and `curl`: `pacman -Syu && pacman -S jq curl`
