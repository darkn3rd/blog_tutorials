# QEMU and Ansible on macOS

This project runs an Ubuntu 26.04 virtual machine with `qemu-system-aarch64` directly,
with no VM manager, and configures it with Ansible. A Makefile drives every step:
downloading the image, creating the disk, building the cloud-init seed, booting QEMU and
shutting it down. The playbook sets up a small web server so there is something to see
once the VM is configured.

## Requirements

- An Apple Silicon Mac. The Makefile uses an arm64 image, Apple's Hypervisor framework
  (`-accel hvf`) and `hdiutil`.
- [QEMU](https://www.qemu.org/), which also provides the UEFI firmware and `qemu-img`
- [Ansible](https://docs.ansible.com/)

Install them with Homebrew:

```bash
brew install qemu ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Downloads the image, creates the disk and seed, starts and stops QEMU |
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
| `make halt` | `mise run halt` | Shut the guest down, stopping QEMU if it ignores the request for 60s |
| `make destroy` | `mise run destroy` | Stop QEMU and delete `.vm/`, keeping the downloaded image |
| `make purge` | `mise run purge` | Delete the downloaded image |

The first `make up` downloads the Ubuntu cloud image, about 1 GB, into `images/`.

Create the VM and configure it:

```bash
make up PROVISION=true
```

Then open <http://localhost:8080>, or check it from the terminal:

```bash
make verify
```

`SSH_PORT` (default 2222), `HTTP_PORT` (8080), `CPUS`, `MEMORY` and `DISK_SIZE` can be
overridden, for example `make up HTTP_PORT=8081`. If you change the ports, pass the same
values to every later `make` command.

## What the Makefile does

| Job | How |
| --- | --- |
| Get the image | `curl`, then check it against Ubuntu's `SHA256SUMS` |
| Create the disk | A `qemu-img` overlay on top of the downloaded image |
| Set up the guest user | A generated SSH key and a cloud-init seed ISO made with `hdiutil` |
| Boot | `qemu-system-aarch64` with UEFI firmware, port forwards and a 9p share |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |
| Track the VM state | QEMU's PID file |
| Shut down | `system_powerdown` over the QEMU monitor socket |

## Changing the configuration

Edit `site/index.html`, then run:

```bash
make provision
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

- **The guest user has your Mac's UID.** The 9p share passes file ownership through, so a
  guest user with a different UID couldn't write to your files in `/workspace`.
  cloud-init creates the user with your UID instead.
- **Don't quote the UID in `user-data`.** A quoted UID makes `cloud-init status --wait`
  exit with status 2, even though cloud-init finished.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.
- **The disk depends on the downloaded image.** It's a small overlay that stores only the
  changes. Moving the project folder breaks the link, so run `make destroy` first.
- **`.vm/` holds the VM's private SSH key.** The project folder, including that key, is
  shared with the guest. The key only opens this VM, and its SSH port listens on
  `127.0.0.1` only.

## Cleaning up

```bash
make destroy
make purge
```

`make destroy` deletes the VM. `make purge` also deletes the downloaded image, so the
next `make up` downloads it again.

## Troubleshooting

### Port 2222 or 8080 in use

Check which process is using the port:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Stop that process, or create the VM on other ports, for example
`make up SSH_PORT=2223 HTTP_PORT=8081`.
