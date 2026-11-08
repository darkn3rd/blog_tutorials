# Vagrant, Apple Virtualization and Ansible on macOS

This project uses Vagrant to create an Ubuntu 26.04 virtual machine and Ansible to
configure it. Vagrant runs the VM with Apple's Virtualization framework through the
[vagrant-provider-avf](https://github.com/sodini-io/vagrant-provider-avf) plugin. The
playbook sets up a small web server so there is something to see once the VM is
configured.

**Status: not fully tested.** The box builds and Ubuntu 26.04 boots, but SSH to the VM
failed in testing with `No route to host`, so the playbook hasn't been run on this VM.
See [Troubleshooting](#troubleshooting).

## Requirements

- macOS on Apple Silicon
- Xcode's command line tools, which the plugin uses to build a small helper for each VM
- [Vagrant](https://developer.hashicorp.com/vagrant)
- The `vagrant-provider-avf` plugin
- `qemu-img`, from QEMU, used once to convert Ubuntu's image for the box
- [Ansible](https://docs.ansible.com/)

Install them:

```bash
xcode-select --install
```

```bash
brew install --cask vagrant
brew install qemu ansible
vagrant plugin install vagrant-provider-avf
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing, after
the Xcode command line tools:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Vagrantfile` | Defines the VM: the box, CPUs, memory, disk and shared folder |
| `box-template/` | Metadata for the local Ubuntu 26.04 box that the Makefile builds |
| `playbook.yaml` | The Ansible playbook that configures the VM |
| `inventory.yaml` | Tells Ansible how to reach the VM, in the `web` group |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page and web server config that the playbook copies into the VM |
| `Makefile` | Builds the box and runs the steps below |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM has 2 CPUs, 4 GiB of memory and a 20 GiB disk. The project folder is shared into
the VM at `/workspace`.

## Usage

| Make | mise | What it does |
| --- | --- | --- |
| `make up` | `mise run up` | Build the box if needed, start the VM and wait for it, without the playbook |
| `make up PROVISION=true` | `PROVISION=true mise run up` | The same, then run the playbook |
| `make provision` | `mise run provision` | Save `vagrant ssh-config`, then run `ansible-playbook` |
| `make verify` | `mise run verify` | `curl` the web page at the VM's address |
| `make url` | `mise run url` | Print the web page's address |
| `make ssh` | `mise run ssh` | `vagrant ssh`, starting in `/workspace` |
| `make status` | `mise run status` | `vagrant status` |
| `make halt` | `mise run halt` | `vagrant halt` |
| `make destroy` | `mise run destroy` | `vagrant destroy --force`, keeping the box |
| `make purge` | `mise run purge` | Delete the local box and the downloaded image |

The first `make up` downloads Ubuntu's cloud image, about 1 GB, into `images/` and builds
a local box from it.

The page isn't on `localhost`. Run `make url` to get its address. For a localhost address,
keep this tunnel running in another terminal:

```bash
vagrant ssh -- -N -L 8080:127.0.0.1:80
```

## How provisioning works

The AVF provider has no provision action, so `vagrant provision` reports that the provider
doesn't support it, and `vagrant up` doesn't provision either. The `Vagrantfile` has no
provisioner. Instead, `make provision` runs Ansible itself:

```bash
vagrant ssh-config > .vagrant/ssh.config
ansible-playbook playbook.yaml
```

`inventory.yaml` passes the saved SSH config to SSH, and `ansible.cfg` makes
`inventory.yaml` the default inventory.

## Changing the configuration

Edit `site/index.html`, then run:

```bash
make provision
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

These are limits of vagrant-provider-avf 0.1.0.

- **There's no published Ubuntu 26.04 box,** so the Makefile builds a local one,
  `local/ubuntu-26.04-arm64`, from Ubuntu's cloud image. The provider documents Ubuntu
  24.04, AlmaLinux 9 and Rocky 9 as supported, so 26.04 is outside its support matrix.
- **Only SSH is forwarded.** The provider has no `forwarded_port` support, so the page is
  served from the VM's NAT address.
- **SSH depends on host-to-guest networking.** The provider's SSH forwarder connects from
  `127.0.0.1` to the VM's `192.168.64.x` address.
- **It uses the provider's shared insecure SSH key.** The box build downloads the private
  key from the provider's repository at tag `0.1.0` and checks it against the public key
  in the installed plugin. The forwarder listens on `127.0.0.1` only.
- **The forwarder's error log can grow quickly** while SSH is unreachable. `make destroy`
  removes it.
- **Each VM holds a full copy of the disk.**

## Cleaning up

```bash
make destroy
make purge
```

`make destroy` deletes the VM. `make purge` also deletes the local box and the downloaded
image, so the next `make up` downloads the image and builds the box again.

## Troubleshooting

### `No route to host` when connecting over SSH

In testing, `make up` kept retrying SSH while the forwarder logged
`Errno::EHOSTUNREACH`, even though the VM had booted and had an address. The likely
cause is macOS Local Network privacy blocking the app that ran Vagrant from reaching the
VM's network. Check that your terminal app is allowed in System Settings under
Privacy & Security, then Local Network, and run `make up` again from that terminal.
