# WSL2, Gentoo and Ansible on Windows

This project builds a Gentoo WSL2 distro from Gentoo's official stage3 tarball and
configures it with Ansible. A Makefile drives every step: downloading the stage3, building
a WSL image from it, importing the image as a distro, starting it and provisioning it. The
playbook sets up a small web server so there is something to see once the machine is
configured.

Ansible doesn't run on Windows, so provisioning works like Vagrant's `ansible_local`
provisioner: it installs Ansible inside the guest, then runs the playbook there against
the guest itself.

## Requirements

- Windows 11 with WSL2 (`wsl --install --no-distribution` if WSL isn't set up yet)
- GNU make
- One of:
  - [PowerShell 7](https://learn.microsoft.com/powershell/) (`pwsh`), to run the steps with `wsl.ps1`
  - [MSYS2](https://www.msys2.org/) or Git Bash, to run them with `wsl.sh`

`curl.exe` and `tar.exe` come with Windows. Install the rest with
[Chocolatey](https://chocolatey.org/install):

```pwsh
choco install -y make powershell-core
```

Or, if you use [mise](https://mise.jdx.dev/), let it install make if it's missing:

```pwsh
mise run deps
```

Run the `make` commands in this folder, from PowerShell or from an MSYS2 or Git Bash
shell. MSYS2 and Git Bash set `MSYSTEM`, and when it's set the Makefile runs the steps
with `wsl.sh`; otherwise it runs them with `wsl.ps1`. Set `RUNNER=sh` or `RUNNER=pwsh` to
choose. Both scripts have the same steps and options.

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | The targets, and which files each step builds |
| `wsl.ps1` | The steps the Makefile runs: download, build, import, start, provision and the rest |
| `wsl.sh` | The same steps, for MSYS2 and Git Bash |
| `image/etc/wsl.conf` | The WSL settings added to the stage3: systemd, hostname, mount options, default user |
| `image.mtree` | Lists what `make image` adds to the stage3, with owners and modes: `wsl.conf`, and links that mask systemd units that don't work under WSL |
| `guest/setup.sh` | Runs as root when the machine is created: adds the `gentoo` user and `/workspace`, and builds the locale WSL passes in |
| `guest/install-ansible.sh` | Runs as root before the playbook: installs Ansible and sudo |
| `playbook.yaml` | The Ansible playbook that configures the guest |
| `inventory.yaml` | Puts the guest in the `web` group, reached with the local connection |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page, and the nginx config template with the port, that the playbook puts in the guest |
| `mise.toml` | `deps`, plus mise tasks that run the Makefile |

The guest is named `gentoo-dev` in WSL, and its hostname is `dev`. The project folder is
linked into it at `/workspace`.

## Usage

| Make | What it does |
| --- | --- |
| `make download` | Download the newest `stage3-amd64-systemd` tarball into `images/` and check its SHA256 |
| `make image` | Build `images/gentoo-wsl.tar`: the stage3 plus `/etc/wsl.conf` |
| `make machine` | `wsl --import` the image into `.vm/`, then run `guest/setup.sh` |
| `make up` | Do whichever of the above are needed, then start the machine, without the playbook |
| `make up PROVISION=true` | The same, then run the playbook |
| `make provision` | Install Ansible in the guest if needed, then run `ansible-playbook` there |
| `make verify` | `curl` the web page |
| `make check-config` | Download Docker's `check-config.sh` and run it in the guest |
| `make ssh` | Open a shell in the guest, starting in `/workspace` |
| `make status` | Report running, stopped or not created |
| `make versions` | Print the Windows, WSL, make and guest Ansible versions |
| `make halt` | `wsl --terminate` the machine |
| `make reload` | `make halt`, then `make up` |
| `make destroy` | `wsl --unregister` the machine and delete `.vm/`, keeping `images/` |
| `make purge` | Delete `images/` |

Every target has a mise task of the same name, such as `mise run up`.

To see what a step would run without running it, add `DRY_RUN=true`, for example
`make up PROVISION=true DRY_RUN=true`. Each command that would change something is
printed as a `What if:` line instead. `wsl.ps1` takes this as `-WhatIf`, and `wsl.sh` as
`--dry-run`. Read-only queries, such as listing distros or
finding the newest stage3, still run. Make decides which steps to run from which files
exist, so on a fresh checkout it lists every step.

Create the machine and configure it:

```pwsh
make up PROVISION=true
```

Then open <http://localhost:8080>, or check it from the terminal:

```pwsh
make verify
```

The first `make up` downloads the stage3, about 300 MB. The first `make provision`
downloads a snapshot of the Gentoo ebuild repository, then Ansible and nginx as binary
packages, so it takes a few minutes.

`HTTP_PORT` (default 8080) sets the port nginx listens on, for example
`make up PROVISION=true HTTP_PORT=8081`. The playbook writes it into the nginx config,
so a change takes effect at the next `make provision`. Pass the same value to
`make verify` and `make status`.

## What the Makefile does

| Job | How |
| --- | --- |
| Get the stage3 | `curl`, finding the newest build from `latest-stage3-amd64-systemd.txt` and checking it against its `.sha256` file |
| Build the image | Windows' `tar.exe` (bsdtar) copies the stage3 and adds the entries in `image.mtree` |
| Create the machine | `wsl --import`, then `guest/setup.sh` as root |
| Keep it running | A `wsl.exe` session in the background that runs `sleep infinity` |
| Know when it's ready | `systemctl is-system-running --wait` |
| Install Ansible | `emerge-webrsync`, then `emerge --getbinpkg app-admin/ansible app-admin/sudo` |
| Provision | `ansible-playbook` in the guest, as the `gentoo` user, with the local connection |
| Shut down | `wsl --terminate` |

Chocolatey's make runs recipes with `cmd.exe` and only honors `SHELL` for a POSIX shell,
so each recipe is a single call to `wsl.ps1`, or to `wsl.sh` under MSYS2. The download, the image and the machine's
virtual disk (`.vm/ext4.vhdx`) are make targets, so make only redoes a step when its
output is missing or out of date.

## Changing the configuration

Edit `site/index.html`, then run:

```pwsh
make provision
```

Ansible copies the new page into the guest and the `Reload nginx` handler reloads the web
server. Run `make provision` again without changes and Ansible reports `changed=0`.

## Checking the kernel for Docker

```pwsh
make check-config
```

This downloads Docker's
[`check-config.sh`](https://github.com/moby/moby/blob/master/contrib/check-config.sh) into
the project folder and runs `bash ./check-config.sh` in the guest. The script reads the
kernel config from `/proc/config.gz`, so what it checks is the WSL kernel, which every WSL
distro on the computer shares, not anything in the Gentoo image. It needs only `bash`,
`zcat` and `grep`, which the stage3 has.

## Things to know

- **Some systemd units are masked.** The stage3 has no machine-id, so systemd treats
  the first start as a first boot, and `systemd-firstboot` would wait at the console for
  answers. `systemd-resolved`, which `nsswitch.conf` asks first, hangs on WSL's DNS proxy;
  without it, lookups use the `resolv.conf` that WSL writes. `image.mtree` masks both.
- **The guest gets your Windows locale.** `wsl.exe` sets `LANG` from the Windows display
  language, such as `en_US.UTF-8`. The stage3 only has `C.UTF-8`, and Ansible won't start
  without a working locale, so `guest/setup.sh` adds that locale with `locale-gen`.

- **WSL2 distros share one VM.** They share the kernel and the network, so port 8080 is
  the same port in every running distro. If something else listens on it, in Windows,
  another distro or another tutorial's VM, use another `HTTP_PORT`.
- **CPUs and memory are set for all of WSL, not per distro.** Change them in
  `%UserProfile%\.wslconfig`, then run `wsl --shutdown`.
- **Windows files appear owned by the `gentoo` user.** `image/etc/wsl.conf` mounts the
  Windows drives with uid 1000 and a umask of 022. With WSL's default mount options, the
  project folder is world-writable, and Ansible ignores an `ansible.cfg` in a
  world-writable folder.
- **Changes to `image/etc/wsl.conf` apply to new machines.** `make image` rebuilds the
  image when the file changes, but the existing machine keeps its copy. Run
  `make destroy up` to recreate it.
- **`make provision` starts the machine** first, creating it if needed, so nginx keeps
  running after the playbook finishes.
- **The machine stays up until `make halt`** or `wsl --shutdown`, because of the
  `sleep infinity` session in the background.
- **`wsl.sh` turns off MSYS2's path conversion.** MSYS2 rewrites arguments that look like
  Unix paths, such as `--cd /workspace`, before it runs a Windows program, so `wsl.sh`
  sets `MSYS2_ARG_CONV_EXCL='*'`. It uses Windows' own `tar.exe`, found with
  `cygpath -S`, because the image step needs bsdtar.

## Cleaning up

```pwsh
make destroy
make purge
```

`make destroy` deletes the machine. `make purge` also deletes the downloaded stage3 and
the built image, so the next `make up` downloads and builds them again.

## Troubleshooting

### Port 8080 in use

```pwsh
$c = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($c) { Get-Process -Id $c.OwningProcess | Select-Object Id, ProcessName, Path } else { 'Port 8080 is free' }
```

A port used by another WSL distro shows up as `wslrelay` or `wslhost`.

### systemd is degraded

`make up` says so when a unit failed to start, which is common for units that expect real
hardware. See which ones:

```pwsh
wsl -d gentoo-dev -- systemctl --failed
```
