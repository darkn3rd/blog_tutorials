# VirtualBox and Ansible on macOS

This project creates an Ubuntu 26.04 virtual machine in VirtualBox using only
`VBoxManage`, VirtualBox's command-line tool, and configures it with Ansible. A Makefile
drives every step: downloading the image, building the disk, defining the VM and booting
it. The playbook sets up a small web server so there is something to see once the VM is
configured.

## Requirements

- An Apple Silicon Mac. The Makefile uses an arm64 image and `hdiutil`.
- [VirtualBox](https://www.virtualbox.org/) 7.2 or later
- `qemu-img`, from QEMU, used once to convert the image into a VirtualBox disk
- [Ansible](https://docs.ansible.com/)

Install them with Homebrew:

```bash
brew install --cask virtualbox
brew install qemu ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Downloads the image, builds the disk and seed, defines and runs the VM |
| `cloud-init/` | The guest's first-boot settings: SSH key, hostname and the `/workspace` mount |
| `playbook.yaml` | The Ansible playbook that configures the VM |
| `inventory.yaml` | Tells Ansible how to reach the VM, in the `web` group |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page and web server config that the playbook copies into the VM |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM is named `dev` and has 2 CPUs, 4 GiB of memory and a 20 GiB disk. The project
folder is shared into the VM at `/workspace`.

## Usage

| Make | mise | What it does |
| --- | --- | --- |
| `make up` | `mise run up` | Create or start the VM and wait for it, without the playbook |
| `make up PROVISION=true` | `PROVISION=true mise run up` | The same, then run the playbook |
| `make provision` | `mise run provision` | `ansible-playbook playbook.yaml` |
| `make verify` | `mise run verify` | `curl` the web page |
| `make ssh` | `mise run ssh` | SSH in, starting in `/workspace` |
| `make status` | `mise run status` | Report the VM state, or `not created` |
| `make halt` | `mise run halt` | Shut the guest down, powering off if it ignores the request for 60s |
| `make destroy` | `mise run destroy` | Delete the VM and `.vm/`, keeping the downloaded image |
| `make purge` | `mise run purge` | Delete the downloaded image |

The first `make up` downloads the Ubuntu cloud image, about 1 GB, into `images/`.

Create the VM and configure it:

```bash
make up PROVISION=true
```

Then open <http://localhost:8080>, or check it from the terminal:

```bash
curl --include http://localhost:8080
```

`SSH_PORT` (default 2222), `HTTP_PORT` (8080), `CPUS`, `MEMORY_MB` and `DISK_SIZE_MB`
can be overridden when the VM is created. If you change the ports, pass the same values to
every later `make` command.

## What the Makefile does

| Job | How |
| --- | --- |
| Get the image | `curl`, then check it against Ubuntu's `SHA256SUMS` |
| Create the disk | `qemu-img convert -O vdi`, then `VBoxManage modifymedium --resize` |
| Set up the guest user | A generated SSH key and a cloud-init seed ISO made with `hdiutil` |
| Define the VM | `createvm`, `modifyvm`, `storagectl`, `storageattach`, `sharedfolder add` |
| Boot | `startvm --type headless` |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |
| Track the VM state | `showvminfo --machinereadable` |
| Shut down | `controlvm acpipowerbutton` |
| Delete | `unregistervm --delete` |

## Changing the configuration

Edit `site/index.html`, then run:

```bash
make provision
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

- **`qemu-img` is needed once.** Ubuntu's arm64 cloud image is in qcow2 format, which
  VirtualBox can't read, so the Makefile converts it to VDI.
- **The disk is a full copy** of the image, about 2.5 GB, made when the VM is created.
- **Guest Additions aren't needed for `/workspace`.** Ubuntu's kernel includes the
  `vboxsf` driver for VirtualBox shared folders. Files the guest creates there appear on
  the Mac as owned by you.
- **The VM is registered with VirtualBox.** It appears in the VirtualBox app and in
  `VBoxManage list vms` as `dev`, but its files stay in `.vm/`.
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
