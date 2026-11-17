# krunkit and Ansible on macOS

This project runs an Ubuntu 26.04 virtual machine with
[krunkit](https://github.com/containers/krunkit), the command-line front end to
[libkrun](https://github.com/containers/libkrun), and configures it with Ansible. There's
no VM manager: a Makefile downloads the image, creates the disk, builds the cloud-init
seed, starts the network and the VM, and shuts them down. The playbook sets up a small web
server so there is something to see once the VM is configured.

libkrun is a small virtual machine monitor built on Apple's Hypervisor framework. It
provides a handful of virtio devices (disks, network, shared folders and a console) and
boots the guest with its own EFI firmware. It's the engine behind Podman's `libkrun`
machine provider, and the one that gives containers GPU access on macOS.

## Requirements

- An Apple Silicon Mac with macOS 14 or later
- [krunkit](https://github.com/containers/krunkit), tested with 1.3.2
- [gvproxy](https://github.com/containers/gvisor-tap-vsock), for the VM's network.
  Homebrew doesn't package it on its own; it comes with Podman.
- `qemu-img`, from QEMU, to convert Ubuntu's qcow2 image to a raw disk
- [Ansible](https://docs.ansible.com/)

Install them with Homebrew:

```bash
brew tap slp/krun
brew install krunkit podman qemu ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

If you already have `gvproxy` somewhere else, set `GVPROXY=/path/to/gvproxy`.

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Downloads the image, creates the disk and seed, starts and stops gvproxy and krunkit |
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
| `make halt` | `mise run halt` | Shut the guest down, stopping krunkit if it ignores the request for 60s, then stop gvproxy |
| `make reload` | `mise run reload` | `make halt`, then `make up` |
| `make destroy` | `mise run destroy` | Stop krunkit and gvproxy and delete `.vm/`, keeping the downloaded image |
| `make purge` | `mise run purge` | Delete the downloaded image and its raw copy |

The first `make up` downloads the Ubuntu cloud image, about 1 GB, into `images/`, and
converts it to a raw image next to it.

Create the VM and configure it:

```bash
make up PROVISION=true
```

Then open <http://localhost:8080>, or check it from the terminal:

```bash
make verify
```

`SSH_PORT` (default 2222), `HTTP_PORT` (8080), `CPUS`, `MEMORY` and `DISK_SIZE` can be
overridden, for example `make up HTTP_PORT=8081`. If you change the
ports, pass the same values to every later `make` command.

## What the Makefile does

| Job | How |
| --- | --- |
| Get the image | `curl`, then check it against Ubuntu's `SHA256SUMS` |
| Create the disk | `qemu-img convert` to raw once, then an APFS clone (`cp -c`) grown with `truncate` |
| Set up the guest user | A generated SSH key and a cloud-init seed ISO made with `hdiutil` |
| Network | `gvproxy`: DHCP, DNS and NAT for the guest, SSH on `127.0.0.1:2222`, and a forward of `127.0.0.1:8080` to port 80 added through its API |
| Boot | `krunkit` with virtio-blk disks, virtio-net to gvproxy, a virtio-fs share and a serial console log |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |
| Track the VM state | krunkit's and gvproxy's PID files |
| Shut down | `POST /vm/state` with `Stop` on krunkit's API socket, which asks the guest to shut down; `HardStop` if it doesn't within 60s |

Compared with the QEMU tutorial, krunkit has no built-in user-mode network or port
forwarding, so gvproxy runs next to it as a second process. It also has no UEFI variable
file to manage, because libkrun brings its own firmware.

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
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.
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
copy, so the next `make up` downloads it again.

## Troubleshooting

### The VM doesn't come up

Check krunkit's log and the guest's console:

```bash
cat .vm/krunkit.log .vm/console.log
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
krunkit's sockets in `.vm/` inside the project folder. If the project lives in a deeply
nested folder, move it somewhere shorter.
