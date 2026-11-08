# Vagrant, QEMU and Ansible on macOS

This project uses Vagrant to create an Ubuntu virtual machine and Ansible to configure it.
Vagrant runs QEMU through the [vagrant-qemu](https://github.com/ppggff/vagrant-qemu)
provider plugin, using Apple's Hypervisor framework. The playbook sets up a small web
server so there is something to see once the VM is configured.

## Requirements

- macOS on Apple Silicon
- [Vagrant](https://developer.hashicorp.com/vagrant)
- [QEMU](https://www.qemu.org/)
- The `vagrant-qemu` plugin
- [Ansible](https://docs.ansible.com/)

Install them with Homebrew and Vagrant:

```bash
brew install --cask vagrant
brew install qemu ansible
vagrant plugin install vagrant-qemu
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

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

The VM runs the `bento/ubuntu-26.04` box with 2 CPUs and 4 GiB of memory. The project
folder is copied into the VM at `/workspace`.

## Usage

| Make | mise | Runs |
| --- | --- | --- |
| `make up` | `mise run up` | `vagrant up --provider=qemu --no-provision` |
| `make up PROVISION=true` | `PROVISION=true mise run up` | `vagrant up --provider=qemu --provision` |
| `make provision` | `mise run provision` | `vagrant provision` |
| `make playbook` | `mise run playbook` | `ansible-playbook playbook.yaml`, without Vagrant |
| `make verify` | `mise run verify` | `curl --include --fail http://localhost:8080` |
| `make ssh` | `mise run ssh` | `vagrant ssh`, starting in `/workspace` |
| `make status` | `mise run status` | `vagrant status` |
| `make halt` | `mise run halt` | `vagrant halt` |
| `make destroy` | `mise run destroy` | `vagrant destroy --force` |
| `make purge` | `mise run purge` | `vagrant box remove`, deleting the downloaded box |

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
runs `ansible-playbook` from your Mac.

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

- **The box is the libvirt build.** vagrant-qemu reads libvirt-format boxes, so Vagrant
  downloads the `libvirt` arm64 build of `bento/ubuntu-26.04`.
- **`/workspace` is a one-way copy.** It's synced with rsync at `vagrant up`, or when you
  run `vagrant rsync`. Files written in the guest don't reach the Mac. The playbook
  doesn't use `/workspace`, so the example isn't affected.
- **SSH listens on all interfaces.** The plugin forwards SSH without a host address, so
  other devices on your network can reach the port. The web port is limited to
  `127.0.0.1` by the `Vagrantfile`.
- **Only one VM can use the default SSH port.** Set `qe.ssh_port` or
  `qe.ssh_auto_correct` in the `Vagrantfile` to run several at once.
- **The disk size isn't set.** It's whatever the box ships with.

## Cleaning up

```bash
make destroy
```

This deletes the VM. The downloaded box stays cached; to remove it as well:

```bash
make purge
```

## Troubleshooting

### Port 8080 in use

Check which process is using the port:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Stop that process, or change the `host` value of the `forwarded_port` line in the
`Vagrantfile` to an open port, such as `8081`.
