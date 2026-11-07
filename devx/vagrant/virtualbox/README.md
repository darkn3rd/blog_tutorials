# Vagrant and Ansible on macOS

This project uses Vagrant to create an Ubuntu virtual machine and Ansible to configure it.
Vagrant runs with its default provider, VirtualBox. The playbook sets up a small web
server so there is something to see once the VM is configured.

## Requirements

- macOS on Apple Silicon or Intel
- [Vagrant](https://developer.hashicorp.com/vagrant)
- [VirtualBox](https://www.virtualbox.org/) 7.1 or later, for Apple Silicon support
- [Ansible](https://docs.ansible.com/)

Install them with Homebrew:

```bash
brew install --cask vagrant virtualbox
brew install ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Vagrantfile` | Defines the VM: the box, CPUs, memory, forwarded port, shared folder and provisioner |
| `playbook.yaml` | The Ansible playbook that configures the VM |
| `inventory.yaml` | The inventory for running `ansible-playbook` directly |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page and web server config that the playbook copies into the VM |
| `Makefile` | Short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

The VM runs the `bento/ubuntu-26.04` box with 2 CPUs and 4 GiB of memory. The project
folder is shared into the VM at `/workspace`.

## Usage

| Make | mise | Runs |
| --- | --- | --- |
| `make up` | `mise run up` | `vagrant up --provider=virtualbox --no-provision` |
| `make up PROVISION=true` | `PROVISION=true mise run up` | `vagrant up --provider=virtualbox --provision` |
| `make provision` | `mise run provision` | `vagrant provision` |
| `make playbook` | `mise run playbook` | `ansible-playbook playbook.yaml`, without Vagrant |
| `make ssh` | `mise run ssh` | `vagrant ssh`, starting in `/workspace` |
| `make status` | `mise run status` | `vagrant status` |
| `make halt` | `mise run halt` | `vagrant halt` |
| `make destroy` | `mise run destroy` | `vagrant destroy --force` |

The first `make up` downloads the box, which takes a while.

Create the VM and configure it:

```bash
make up PROVISION=true
```

Then open <http://localhost:8080>, or check it from the terminal:

```bash
curl --include http://localhost:8080
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

`vagrant ssh-config` prints the SSH settings for the VM: its address, port, user and
key. `inventory.yaml` passes that file to SSH, and `ansible.cfg` makes `inventory.yaml`
the default inventory. The SSH port can change when the VM restarts, so `make playbook`
saves the settings again each time.

Once `.vagrant/ssh.config` exists, you can also run any Ansible command yourself, such as:

```bash
ansible web -m ping
```

## Changing the configuration

Edit `site/index.html`, then run either of these:

```bash
make provision
make playbook
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Cleaning up

```bash
make destroy
```

This deletes the VM. The downloaded box stays cached; to remove it as well:

```bash
vagrant box remove bento/ubuntu-26.04
```

## Troubleshooting

### Port 8080 in use

If your local server fails to start because port 8080 is already taken, check which process is using it by running:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

To resolve the conflict, you can either terminate the conflicting process or change your Vagrant configuration:

* **Option 1**: Stop the conflicting process. Use the PID from the command above to kill the program (e.g., `kill -9 <PID>`).
* **Option 2:** Change the Vagrant port. Open your `Vagrantfile` and update the `host` value on the `forwarded_port` line to an open port, such as `8081`.