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

- An Apple Silicon Mac. The Makefile uses an arm64 image.
- [vfkit](https://github.com/crc-org/vfkit), tested with 0.6.4
- [gvproxy](https://github.com/containers/gvisor-tap-vsock), for the VM's network.
  Homebrew doesn't package it on its own; it comes with Podman, along with vfkit.
- `qemu-img`, from QEMU, to convert Ubuntu's qcow2 image to a raw disk
- [Ansible](https://docs.ansible.com/)

Install them with Homebrew:

```bash
brew install podman qemu ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

The Makefile uses `vfkit` and `gvproxy` from your `PATH` if they're there, and Podman's
copies otherwise. To use others, set `VFKIT=/path/to/vfkit` or `GVPROXY=/path/to/gvproxy`.

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Downloads the image, creates the disk, starts and stops gvproxy and vfkit |
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

`SSH_PORT` (default 2222), `HTTP_PORT` (8080), `CPUS`, `MEMORY` (in MiB, default 4096)
and `DISK_SIZE` can be overridden, for example `make up HTTP_PORT=8081`. If you change the
ports, pass the same values to every later `make` command.

## What the Makefile does

| Job | How |
| --- | --- |
| Get the image | `curl`, then check it against Ubuntu's `SHA256SUMS` |
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
copy, so the next `make up` downloads it again.

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
