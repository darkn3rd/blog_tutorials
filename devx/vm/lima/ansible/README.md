# Lima and Ansible

An Ubuntu LTS VM on macOS, created by [Lima](https://lima-vm.io/) and configured by
Ansible from the host.

## Requirements

You need [Lima](https://lima-vm.io/) and [Ansible](https://docs.ansible.com/), plus `make`, which comes with Apple's command line tools (`xcode-select --install`).

The simplest way to get them is to run this from this folder. It only installs what's missing, using [Homebrew](https://brew.sh/):

```bash
make deps
```

### Other ways to install

Use any one of these instead.

**Homebrew, directly:**

```bash
brew install lima ansible
```

**Homebrew, using this project's `Brewfile`:**

```bash
brew bundle
```

This may also upgrade Lima or Ansible if you already have older versions.

**[mise](https://mise.jdx.dev/) for Lima, with Ansible from Homebrew if it's missing:**

```bash
mise trust      # allow mise to load this project's mise.toml
mise install    # install lima
mise run deps   # install ansible if it's missing
```

**[uv](https://docs.astral.sh/uv/) or [pipx](https://pipx.pypa.io/) for Ansible, if you already have Lima:**

```bash
uv tool install ansible-core
```

```bash
pipx install --include-deps ansible
```

## Usage

```bash
make versions   # print macOS, lima, and ansible versions
make up         # download vm image and launch vm
make provision  # run ansible playbook on guest
make verify     # run curl to verify
make ssh        # log into guest
make halt       # shutdown guest
make destroy    # destroy vm
make purge      # delete downloaded images
```

`make purge` runs `limactl prune`, which empties Lima's whole download cache, including images that other Lima VMs use.

Note that launching the system will not automatically provision the systems.  To enable this by default, set `PROVISION=true`

```bash
PROVISION=true make up
```

### Optional: Using mise

[mise](https://mise.jdx.dev/) can manage both the commands and the Lima install from `mise.toml`, without needing `make`.

```bash
mise tasks      # list the tasks

mise run deps
mise run versions
mise run up
mise run provision
mise run verify
mise run ssh
mise run halt
mise run destroy
mise run purge
```

`PROVISION` works the same way:

```bash
PROVISION=true mise run up
```

### Optional: Using just

[just](https://just.systems/) runs the same commands from the `Justfile`, without needing `make` or `mise`.

```bash
brew install just

just            # list the recipes
just deps
just versions
just up
just provision
just verify
just ssh
just halt
just destroy
just purge
```

`PROVISION` works here too:

```bash
PROVISION=true just up
```

## Measured results

One run of each step, not a benchmark. Host: Apple Silicon Mac on macOS 26 (Darwin 25.6),
Lima 2.2.1, ansible-core 2.21.5, tested 2026-11-01. These runs predate the `PROVISION`
switch, when `make up` always ran the playbook, so every `make up` time here includes it.
The tables below were measured before nginx was added, except where noted.

| Step | Time |
| --- | --- |
| First `make up`, including image download | About 3m 15s |
| `make up` after `make destroy`, image cached | 33s |
| The same step with the nginx-only playbook | 38s |
| `make up` from stopped | 9s |
| `make up` while running | 3s |
| `make provision` with nothing to change | 3s |
| `make halt` | 1s |
| `make destroy` | Under 1s |

| Check | Result |
| --- | --- |
| Guest OS | Ubuntu 26.04.1 LTS, kernel 7.0.0-34-generic, aarch64 |
| VM backend | `vz` (Apple Virtualization.framework), Lima's choice on this host |
| `/workspace` mount | virtiofs, writable from the guest and visible on the host |
| Second playbook run | `changed=0` |
| Instance size on disk | 2.5 GB in `~/.lima/dev` |
| Lima download cache | 3.3 GB in `~/Library/Caches/lima` |

Handler behaviour, measured with nginx 1.28.3:

| Action | Handler | nginx master PID | nginx worker PIDs |
| --- | --- | --- | --- |
| Edit the page, then `make provision` | Ran | 1084, unchanged | 1085 and 1086 replaced by 2144 and 2145 |
| `make provision` with no edit | Skipped | 1084, unchanged | 2144 and 2145, unchanged |
