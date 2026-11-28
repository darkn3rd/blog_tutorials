# vfkit and Ansible on macOS

This project runs an Ubuntu 26.04 virtual machine with
[vfkit](https://github.com/crc-org/vfkit) and configures it with Ansible. There's no VM
manager: a Makefile downloads the image, creates the disk, writes the cloud-init files,
starts the network and the VM, and shuts them down. The playbook sets up a small web
server so there is something to see once the VM is configured.

vfkit is a small command-line program that runs a VM with Apple's Virtualization
framework, the same framework Lima uses. Each `--device` flag adds one virtio device:
disks, network, shared folders, a console and a random-number generator. It's what Podman
and CRC use to run their VMs on a Mac.

## Requirements

- A Mac with Apple Silicon or an Intel processor. The VM runs the same architecture as the
  Mac, and the Makefile picks Ubuntu's arm64 or amd64 image to match.
- [vfkit](https://github.com/crc-org/vfkit), tested with 0.6.4
- [gvproxy](https://github.com/containers/gvisor-tap-vsock), for the VM's network.
  Homebrew doesn't package it on its own; it comes with Podman, along with vfkit. Podman's
  Homebrew formula is Apple Silicon only, so on an Intel Mac there's nothing to install:
  the Makefile downloads both.
- `qemu-img`, from QEMU, to convert Ubuntu's qcow2 image to a raw disk
- [Ansible](https://docs.ansible.com/)

On Apple Silicon, install them with Homebrew:

```bash
brew install podman qemu ansible
```

On an Intel Mac, install the other two:

```bash
brew install qemu ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing. It knows
which kind of Mac it's on:

```bash
mise run deps
```

The Makefile uses `vfkit` and `gvproxy` from your `PATH` if they're there, then Podman's
copies, and otherwise downloads vfkit v0.6.4 and gvproxy v0.9.1 into `bin/`. Both releases
are universal binaries, so the download works on either kind of Mac. The Makefile checks
gvproxy against the `sha256sums` file published with the release. vfkit publishes no
checksums, so it checks a SHA-256 recorded in the Makefile. To use others, set
`VFKIT=/path/to/vfkit` or `GVPROXY=/path/to/gvproxy`.

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Downloads the image, and vfkit and gvproxy when you don't have them, creates the disk, starts and stops gvproxy and vfkit |
| `cloud-init/` | The guest's first-boot settings: user, SSH key, hostname and the `/workspace` mount |
| `playbook.yaml` | The Ansible playbook that configures the VM |
| `inventory.yaml` | Tells Ansible how to reach the VM, in the `web` group |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page and web server config that the playbook copies into the VM |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM has 2 CPUs, 4 GiB of memory and a 20 GiB disk. The project folder is shared into
the VM at `/workspace`.

## Usage

| Make | mise | What it does |
| --- | --- | --- |
| `make up` | `mise run up` | Create or start the VM and wait for it, without the playbook |
| `make up PROVISION=true` | `PROVISION=true mise run up` | The same, then run the playbook |
| `make provision` | `mise run provision` | `ansible-playbook playbook.yaml` |
| `make verify` | `mise run verify` | `curl` the web page |
| `make ssh` | `mise run ssh` | SSH in, starting in `/workspace` |
| `make status` | `mise run status` | Report running, stopped or not created |
| `make halt` | `mise run halt` | Shut the guest down, stopping vfkit if it ignores the request for 60s, then stop gvproxy |
| `make reload` | `mise run reload` | `make halt`, then `make up` |
| `make destroy` | `mise run destroy` | Stop vfkit and gvproxy and delete `.vm/`, keeping the downloaded image |
| `make purge` | `mise run purge` | Delete the downloaded image and its raw copy, and the vfkit and gvproxy downloaded into `bin/` |

The first `make up` downloads the Ubuntu cloud image, about 1 GB, into `images/`, and
converts it to a raw image next to it. If you don't have vfkit and gvproxy, it also
downloads them, about 95 MB together, into `bin/`.

Create the VM and configure it:

```bash
make up PROVISION=true
```

Then open <http://localhost:8080>, or check it from the terminal:

```bash
make verify
```

`SSH_PORT` (default 2222), `HTTP_PORT` (8080), `CPUS`, `MEMORY` (in MiB, default 4096)
and `DISK_SIZE` can be overridden, for example `make up HTTP_PORT=8081`. If you change the
ports, pass the same values to every later `make` command.

## What the Makefile does

| Job | How |
| --- | --- |
| Get vfkit and gvproxy | From your `PATH` or Podman if they're there, otherwise `curl` the releases into `bin/` and check their checksums |
| Get the image | `curl` Ubuntu's arm64 or amd64 image to match the Mac, then check it against `SHA256SUMS` |
| Create the disk | `qemu-img convert` to raw once, then an APFS clone (`cp -c`) grown with `truncate` |
| Set up the guest user | A generated SSH key in `user-data`; vfkit's `--cloud-init` flag turns `user-data` and `meta-data` into a seed disk |
| Firmware | `--bootloader efi`, with the EFI variable store in `.vm/efi-vars.fd`, created on the first boot |
| Network | `gvproxy`: DHCP, DNS and NAT for the guest, SSH on `127.0.0.1:2222`, and a forward of `127.0.0.1:8080` to port 80 added through its API |
| Boot | `vfkit` with a virtio-blk disk, virtio-net to gvproxy, a virtio-fs share, a serial console log and virtio-rng |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |
| Track the VM state | vfkit's and gvproxy's PID files |
| Shut down | `POST /vm/state` with `Stop` on vfkit's API socket, which asks the guest to shut down; `HardStop` if it doesn't within 60s |

vfkit has its own network option, `--device virtio-net,nat`, which uses macOS's built-in
NAT. The guest gets an address on the Mac's `192.168.64.0/24` network, but nothing is
forwarded to `localhost`, so this project uses gvproxy instead.

## Changing the configuration

Edit `site/index.html`, then run:

```bash
make provision
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

- **The guest gets its address from gvproxy.** gvproxy hands out `192.168.127.2` to the
  MAC address `5a:94:ef:e4:0c:ee`, and its port forwards point there, so the Makefile
  gives the VM that MAC.
- **The guest user has your Mac's UID.** virtio-fs passes file ownership through, so a
  guest user with a different UID couldn't write to your files in `/workspace`.
  cloud-init creates the user with your UID instead.
- **Don't quote the UID in `user-data`.** A quoted UID makes `cloud-init status --wait`
  exit with status 2, even though cloud-init finished.
- **cloud-init runs once per VM.** vfkit attaches the seed disk on every boot, but
  cloud-init only acts on it the first time. Changes to `cloud-init/` apply after
  `make destroy up`.
- **The disk is a clone of the raw image.** APFS shares the unchanged blocks, so it takes
  little space at first, but `ls` reports the full 20 GiB.
- **`.vm/` holds the VM's private SSH key.** The project folder, including that key, is
  shared with the guest. The key only opens this VM, and its SSH port listens on
  `127.0.0.1` only.

## Cleaning up

```bash
make destroy
make purge
```

`make destroy` deletes the VM. `make purge` also deletes the downloaded image and its raw
copy, and the vfkit and gvproxy in `bin/` if the Makefile downloaded them, so the next
`make up` downloads them again.

## Troubleshooting

### The VM doesn't come up

Check vfkit's log and the guest's console:

```bash
cat .vm/vfkit.log .vm/console.log
```

`.vm/gvproxy.log` has the network side.

### Port 2222 or 8080 in use

Check which process is using the port:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Stop that process, or create the VM on other ports, for example
`make up SSH_PORT=2223 HTTP_PORT=8081`.

### Socket path too long

macOS limits Unix socket paths to 104 characters, and the Makefile puts gvproxy's and
vfkit's sockets in `.vm/` inside the project folder. If the project lives in a deeply
nested folder, move it somewhere shorter.

## Apple Silicon and Intel

The same Makefile runs on both. What differs is the guest and where the tools come from:

| | Apple Silicon | Intel |
| --- | --- | --- |
| Guest image | Ubuntu arm64 | Ubuntu amd64 |
| vfkit and gvproxy | Podman's copies, or your `PATH` | Your `PATH`, or downloaded into `bin/` |
| Needs `sudo` | No | No |

The guest runs the same architecture as the Mac, because the Virtualization framework
doesn't emulate another one. The Makefile reads the architecture from `uname -m`, which
reports `x86_64` in a terminal running under Rosetta on an Apple Silicon Mac, so there it
would pick the amd64 image. That case wasn't tested; run `make` from a native terminal.

### Tested

**On an Intel Mac** (macOS 26.6.2, an Intel Core i5-1038NG7, vfkit 0.6.4 and gvproxy 0.9.1
downloaded by the Makefile, Ubuntu 26.04.1 amd64, Ansible core 2.21):

- A fresh `make up PROVISION=true` booted the VM, Ansible reported `failed=0`, and
  `make verify` returned `200 OK` from `localhost:8080`
- The guest reported `x86_64` and the `apple` virtualization type, and its root disk grew to
  19 GB
- The virtio-fs share was mounted at `/workspace` and writable
- `make provision` a second time reported `changed=0`
- The guest stayed up through 3 minutes idle, with the page still served
- `make halt` took 3 seconds, `make up` from a stopped VM 12 seconds, `make reload`
  16 seconds and `make destroy` 4 seconds, which left no vfkit or gvproxy process behind
- `make purge`, which removed the image, its raw copy and the downloaded tools
- `mise run deps` and `mise run versions`

The timings are from single runs.

**On Apple Silicon** the tutorial was tested before these changes, and none of the
changes were run on one. The Makefile's architecture switch picks the arm64 image name when
told it's on `arm64`, which was checked by overriding `ARCH`. Not tested on Apple Silicon:
the download of vfkit and gvproxy, and the ad-hoc signature the Makefile gives gvproxy
as a precaution, because Apple Silicon refuses unsigned code.

**Not tested on either:** the image download, because the amd64 image was copied into
`images/` instead; and `make ssh`.
