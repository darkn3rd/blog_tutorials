# Vagrant, libvirt and Ansible on Linux

This project uses Vagrant to create an Ubuntu virtual machine and Ansible to configure it.
Vagrant runs the VM through the [vagrant-libvirt](https://vagrant-libvirt.github.io/vagrant-libvirt/)
provider plugin. libvirt runs QEMU with KVM. The playbook sets up a small web server so
there is something to see once the VM is configured.

It uses the same box as [`vagrant/qemu/ansible`](../../qemu/ansible), the libvirt build of
`hako/ubuntu-26.04`, for the host's architecture.

## Requirements

- Linux on x86_64 or arm64, with KVM (`/dev/kvm` exists)
- [Vagrant](https://developer.hashicorp.com/vagrant)
- [libvirt](https://libvirt.org/) and QEMU
- The `vagrant-libvirt` plugin
- [Ansible](https://docs.ansible.com/)
- Your user in the `libvirt` group

On Debian or Ubuntu, install Vagrant from HashiCorp's apt repository. Ubuntu's own
`vagrant` package is older.

```bash
REPO=https://apt.releases.hashicorp.com
KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg
CODENAME=$(. /etc/os-release
  echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

wget -O - "$REPO/gpg" | sudo gpg --dearmor -o "$KEYRING"
echo "deb [signed-by=$KEYRING] $REPO $CODENAME main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update && sudo apt-get install -y vagrant
```

Then install libvirt, the headers the plugin builds against, and Ansible, and install the
plugin:

```bash
sudo apt-get install -y qemu-kvm libvirt-daemon-system \
  libvirt-clients libvirt-dev build-essential ansible

vagrant plugin install vagrant-libvirt
```

Add yourself to the `libvirt` group, then log out and back in:

```bash
sudo usermod -aG libvirt "$USER"
```

Or, if you use [mise](https://mise.jdx.dev/), once Vagrant is installed let it install
whichever of the rest are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Vagrantfile` | Defines the VM: the box, CPUs, memory, forwarded port, synced folder and provisioner |
| `playbook.yaml` | The Ansible playbook that configures the VM |
| `inventory.yaml` | The inventory for running `ansible-playbook` directly |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page and web server config that the playbook copies into the VM |
| `Makefile` | Short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

The VM runs the [`hako/ubuntu-26.04`](https://github.com/darkn3rd/hako) box, built from
Ubuntu's official 26.04 cloud image, with 2 CPUs and 4 GiB of memory. The box isn't on
HashiCorp's registry, so the `Vagrantfile` sets `box_url` to its catalog. The project
folder is copied into the VM at `/workspace`.

## Usage

| Make | mise | Runs |
| --- | --- | --- |
| `make up` | `mise run up` | `vagrant up --provider=libvirt --no-provision` |
| `make up PROVISION=true` | `PROVISION=true mise run up` | `vagrant up --provider=libvirt --provision` |
| `make provision` | `mise run provision` | `vagrant provision` |
| `make playbook` | `mise run playbook` | `ansible-playbook playbook.yaml`, without Vagrant |
| `make verify` | `mise run verify` | `curl --include --fail http://localhost:8080` |
| `make ssh` | `mise run ssh` | `vagrant ssh`, starting in `/workspace` |
| `make status` | `mise run 

Then open <http://localhost:8080>, or check it from the terminal:
status` | `vagrant status` |
| `make halt` | `mise run halt` | `vagrant halt` |
| `make reload` | `mise run reload` | `vagrant reload --no-provision` |
| `make destroy` | `mise run destroy` | `vagrant destroy --force` |
| `make purge` | `mise run purge` | `vagrant box remove`, and deletes the box's copy in libvirt's storage pool |

The first `make up` downloads the box, which takes a while.

Create the VM and configure it:

```bash
make up PROVISION=true
```

Then open <http://localhost:8080>, or check it from the terminal:

```bash
make verify
```

## How provisioning works

There are two ways to run the playbook, and both put the VM in a `web` group, which is
the group the playbook targets.

### Through Vagrant

`make provision` runs `vagrant provision`. Vagrant's built-in Ansible provisioner writes
its own inventory, with the `web` group set by `ansible.groups` in the `Vagrantfile`, and
runs `ansible-playbook` from the host.

Plain `vagrant up` provisions a new VM on its first boot only. Here `make up` doesn't
provision unless `PROVISION=true` is set, so creating the VM and configuring it are
separate steps.

### Directly with Ansible

`make playbook` runs Ansible without Vagrant's provisioner. It does two things:

```bash
vagrant ssh-config > .vagrant/ssh.config
ansible-playbook playbook.yaml
```

`vagrant ssh-config` prints the SSH settings for the VM. `inventory.yaml` passes that file
to SSH, and `ansible.cfg` makes `inventory.yaml` the default inventory.

## Changing the configuration

Edit `site/index.html`, then run either of these:

```bash
make provision
make playbook
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run either again without changes
and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

- **The box is the libvirt build.** It's the same box as `vagrant/qemu`, and Vagrant picks
  the amd64 or arm64 build to match the host.
- **The VM has its own network.** vagrant-libvirt creates a libvirt network named
  `vagrant-libvirt` (192.168.121.0/24), and Vagrant connects over SSH to the VM's address
  on it, not to a forwarded port. That network is only reachable from the host.
- **Port 8080 is an SSH tunnel.** vagrant-libvirt forwards ports by running `ssh -L` on the
  host. The `Vagrantfile` binds it to `127.0.0.1`.
- **`/workspace` is a one-way copy.** libvirt's default synced folder type is NFS, which
  needs an NFS server and `sudo` on the host, so the `Vagrantfile` uses rsync instead. It
  copies at `vagrant up`, or when you run `vagrant rsync`. Files written in the guest
  don't reach the host. The playbook doesn't use `/workspace`, so the example isn't
  affected.
- **The box is copied into libvirt's storage pool.** On first use, vagrant-libvirt uploads
  the box image to the `default` pool, under `/var/lib/libvirt/images`, and each VM's disk
  is a copy-on-write layer on top. `vagrant box remove` doesn't delete that copy, so
  `make purge` deletes it with `virsh vol-delete`. In between, vagrant-libvirt prints
  that you have to delete the image from the storage pool manually; `make purge` does
  that next. It refuses to run while the VM still exists, since the VM's disk depends
  on that image.
- **It uses the system libvirt.** vagrant-libvirt connects to `qemu:///system`, which is
  why your user needs the `libvirt` group.
- **The disk size isn't set.** It's whatever the box ships with (64 GiB, allocated as
  it's used).
- **`[fog][WARNING] Unrecognized arguments: libvirt_ip_command`** is printed by
  vagrant-libvirt's libraries on every command, and is harmless.

## Cleaning up

```bash
make destroy
```

This deletes the VM. The downloaded box stays cached; to remove it as well:

```bash
make purge
```

## Troubleshooting

### Can't connect to libvirt

Vagrant, `virsh` or `make purge` fails with:

```text
Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied
```

You don't need `sudo`: your login session isn't in the `libvirt` group yet. Check with `id -nG`. If `libvirt`
is listed in `/etc/group` for you but not by `id`, log out and back in. To use it in one
shell without logging out:

```bash
newgrp libvirt
```

### `ansible-playbook: command not found` with pyenv

Vagrant runs `ansible-playbook` from your `PATH`. If Ansible is installed in a pyenv
virtualenv, select it first, such as `export PYENV_VERSION=ansible-3.10.4` or
`pyenv shell ansible-3.10.4`.

### Port 8080 in use

Check which process is using the port:

```bash
ss -ltnp 'sport = :8080'
```

Stop that process, or change the `host` value of the `forwarded_port` line in the
`Vagrantfile` to an open port, such as `8081`.
