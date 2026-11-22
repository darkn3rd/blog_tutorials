# libvirt and Ansible on Linux

This project runs an Ubuntu 26.04 virtual machine with libvirt and `virsh`, with no VM
manager on top, and configures it with Ansible. A Makefile drives every step:
downloading the image, copying it into libvirt's storage pool, building the cloud-init
seed, defining the VM from an XML file, booting it and shutting it down. libvirt runs
the VM with QEMU and KVM. The playbook sets up a small web server so there is something
to see once the VM is configured.

It's the Linux counterpart of [`qemu/ansible`](../../qemu/ansible), which runs QEMU by
hand on a Mac. Here libvirt starts QEMU, so the Makefile writes a domain XML file
instead of QEMU flags.

## Requirements

- Linux on x86_64, with KVM (`/dev/kvm` exists). The Makefile uses the amd64 image and
  a `q35` machine.
- [libvirt](https://libvirt.org/) and QEMU, with the system libvirt running
  (`qemu:///system`) and its `default` storage pool and network
- `mtools`, to build the cloud-init seed
- `rsync`
- [Ansible](https://docs.ansible.com/)
- Your user in the `libvirt` group

On Debian or Ubuntu:

```bash
sudo apt-get install -y qemu-kvm libvirt-daemon-system \
  libvirt-clients mtools rsync ansible
```

```bash
sudo usermod -aG libvirt "$USER"
```

Then log out and back in, so the group takes effect.

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Downloads the image, creates the volumes and seed, defines, starts and stops the VM |
| `domain.xml` | The VM's libvirt definition, with `@...@` values the Makefile fills in |
| `cloud-init/` | The guest's first-boot settings: user, SSH key, hostname and `/workspace` |
| `playbook.yaml` | The Ansible playbook that configures the VM |
| `inventory.yaml` | Tells Ansible how to reach the VM, in the `web` group |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page and web server config that the playbook copies into the VM |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM, named `dev` in libvirt, has 2 CPUs, 4 GiB of memory and a 20 GiB disk. The
project folder is copied into the VM at `/workspace`.

## Usage

| Make | mise | What it does |
| --- | --- | --- |
| `make up` | `mise run up` | Create or start the VM and wait for it, without the playbook |
| `make up PROVISION=true` | `PROVISION=true mise run up` | The same, then run the playbook |
| `make provision` | `mise run provision` | `ansible-playbook playbook.yaml` |
| `make verify` | `mise run verify` | `curl` the web page |
| `make url` | `mise run url` | Print the web page's address |
| `make sync` | `mise run sync` | Copy the project to `/workspace` again |
| `make ssh` | `mise run ssh` | SSH in, starting in `/workspace` |
| `make status` | `mise run status` | Report running, shut off or not created, and the address |
| `make halt` | `mise run halt` | `virsh shutdown`, forcing the VM off if it ignores it for 60s |
| `make reload` | `mise run reload` | `make halt`, then `make up` |
| `make destroy` | `mise run destroy` | Delete the VM and its volumes, keeping the image |
| `make purge` | `mise run purge` | Delete the downloaded image and its copy in the pool |

The first `make up` downloads the Ubuntu cloud image, about 860 MB, into `images/`, and
copies it into the storage pool.

Create the VM and configure it:

```bash
make up PROVISION=true
```

The VM gets its address from libvirt's `default` network, so the page isn't on
`localhost`. Print its address and open it, or check it from the terminal:

```bash
make url
```

```bash
make verify
```

`CPUS`, `MEMORY` (in MiB), `DISK_SIZE`, `NAME`, `POOL` and `NETWORK` can be overridden,
for example `make up NAME=dev2`. They take effect when the VM is created, so change them
before `make up`, or after `make destroy`. If you change `NAME`, pass it to every later
`make` command.

## What the Makefile does

| Job | How |
| --- | --- |
| Get the image | `curl`, then check it against Ubuntu's `SHA256SUMS` |
| Put it where libvirt can read it | `virsh vol-create-as` and `virsh vol-upload` into the `default` pool |
| Create the disk | `virsh vol-create-as` with `--backing-vol`: a qcow2 overlay on the image |
| Set up the guest user | A generated SSH key and a cloud-init seed: a FAT image labelled `CIDATA`, made with `mformat` and `mcopy` |
| Define the VM | Fill in `domain.xml`, then `virsh define` |
| Boot | `virsh start` |
| Find the VM | `virsh domifaddr`, which reads libvirt's DHCP leases |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |
| Share the project | `rsync` to `/workspace` |
| Track the VM state | `virsh domstate` |
| Shut down | `virsh shutdown`, which sends an ACPI power button press |
| Delete it | `virsh undefine --remove-all-storage` |

## Changing the configuration

Edit `site/index.html`, then run:

```bash
make provision
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

- **It's KVM, with a q35 chipset.** `<domain type='kvm'>` runs the guest on the CPU
  through KVM. `machine='q35'` only picks the virtual chipset QEMU presents, a newer one
  with PCI Express than the default `pc`. `type='qemu'` would emulate the CPU instead,
  much more slowly.
- **The disk and seed live in libvirt's storage pool.** The system libvirt runs QEMU as
  the `libvirt-qemu` user, which can't read files in your home folder. So the Makefile
  uploads the image and seed to the `default` pool, under `/var/lib/libvirt/images`,
  and keeps only the SSH key, seed source and generated XML in `.vm/`.
- **`domain.xml` uses file paths, not pool references.** libvirt can refer to a volume
  by pool and name (`<disk type='volume'>`), but on Ubuntu the AppArmor profile libvirt
  writes for each VM then leaves out the image that the disk is layered on, and QEMU
  fails with `Permission denied`. The Makefile looks up each volume's path with
  `virsh vol-path` instead.
- **`/workspace` is a one-way copy.** QEMU can't read your home folder (see above), so
  the project can't be shared live as in `qemu/ansible`. `make up` copies it with
  rsync; run `make sync` to copy it again. Files written in the guest don't reach the
  host. The playbook doesn't use `/workspace`, so the example isn't affected.
- **The VM is on libvirt's `default` network.** It's NAT on `virbr0`, 192.168.122.0/24,
  reachable from the host but not from other machines. Its address can change after
  `make destroy`.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after
  `make destroy up`.
- **The image is shared.** Every VM created here is a small overlay on the one base
  volume. `make purge` refuses to delete it while the VM still exists.
- **The VM keeps running after the shell exits.** It belongs to the system libvirt, not
  to your session. `virsh --connect qemu:///system list --all` shows it.

## Cleaning up

```bash
make destroy
```

```bash
make purge
```

`make destroy` deletes the VM and its disk and seed volumes. `make purge` also deletes
the downloaded image, both in `images/` and in the storage pool, so the next `make up`
downloads it again.

## Troubleshooting

### Can't connect to libvirt

`make` stops with `Can't connect to libvirt at qemu:///system`, and `virsh` itself
fails with:

```text
Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied
```

You don't need `sudo`: your login session isn't in the `libvirt` group yet. Check with `id -nG`. If `libvirt`
is listed in `/etc/group` for you but not by `id`, log out and back in. To use it in one
shell without logging out:

```bash
newgrp libvirt
```

### No address, or SSH doesn't come up

Watch the guest boot on its serial console (press `Ctrl+]` to leave):

```bash
virsh --connect qemu:///system console dev
```

### `ansible-playbook: command not found` with pyenv

`make provision` runs `ansible-playbook` from your `PATH`. If Ansible is installed in a
pyenv virtualenv, select it first, for example with `pyenv shell <version>`.
