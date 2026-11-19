# Building a Vagrant box for VirtualBox with Packer on macOS

This project uses [Packer](https://developer.hashicorp.com/packer) to turn Ubuntu's
official 26.04 cloud image into a Vagrant box for VirtualBox. Packer imports the cloud
image's disk into a VirtualBox VM, cloud-init adds the user Vagrant needs, a script
cleans up, and Packer's Vagrant post-processor packages the VM as a box. The box is
named `local/ubuntu-26.04`.

It's a small, single-purpose example of how Packer builds an image: one source, one
build block, one provisioner and one post-processor.

## Requirements

- macOS on Apple Silicon
- [Packer](https://developer.hashicorp.com/packer) 1.10 or newer
- [VirtualBox](https://www.virtualbox.org/) 7.1 or newer, the first release that
  officially supports Apple Silicon Macs
- [Vagrant](https://developer.hashicorp.com/vagrant), to add and test the box. Packer
  also logs into the build VM with Vagrant's insecure key, which comes with Vagrant.

Install them with Homebrew:

```bash
brew install hashicorp/tap/packer
brew install --cask vagrant virtualbox
```

Install Packer from HashiCorp's tap: Homebrew's own `packer` formula stopped at 1.9.4.

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `ubuntu.pkr.hcl` | The Packer template: the plugins, variables, VirtualBox source and build |
| `cloud-init/user-data` | Creates the `vagrant` user with passwordless sudo and Vagrant's insecure public keys |
| `cloud-init/meta-data` | The instance ID and hostname cloud-init expects in a seed |
| `scripts/cleanup.sh` | Runs in the build VM before packaging and removes state tied to that one VM |
| `test/Vagrantfile` | An ordinary Vagrant project that uses the finished box |
| `Makefile` | The build steps and short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

The Makefile downloads the cloud image to `images/`, writes the OVF that Packer imports
to `.build/ovf/` and writes the box to `output/`. Packer works in `.build/packer/` while
it builds.

## Usage

| Make | mise | Does |
| --- | --- | --- |
| `make all` | `mise run all` | `box`, `add` and `test`, in that order |
| `make image` | `mise run image` | Downloads the cloud image and checks its SHA-256 checksum |
| `make ovf` | `mise run ovf` | Wraps the cloud image's disk in an OVF for Packer to import |
| `make init` | `mise run init` | `packer init`, installing the VirtualBox and Vagrant plugins |
| `make validate` | `mise run validate` | `packer validate`, checking the template |
| `make box` | `mise run box` | `packer build`, writing `output/ubuntu-26.04-virtualbox.box`, starting with `ovf` |
| `make add` | `mise run add` | `vagrant box add`, naming the box `local/ubuntu-26.04` |
| `make test` | `mise run test` | Starts a VM from the added box, then runs `verify` |
| `make verify` | `mise run verify` | Prints the test VM's user, sudo access, OS and disk size |
| `make ssh` | `mise run ssh` | `vagrant ssh` into the test VM |
| `make destroy` | `mise run destroy` | Deletes the test VM |
| `make clean` | `mise run clean` | `destroy`, then deletes the OVF, the box file and Packer's work directory |
| `make purge` | `mise run purge` | `clean`, then removes the added box and the downloaded image |

Build the box, add it and try it:

```bash
make all
```

The first run downloads the cloud image, about 900 MB. After that, `make box` takes
about two and a half minutes. Adding the box and starting the test VM take a few more,
since Vagrant unpacks and imports a 900 MB box. A successful test ends like this:

```text
user: vagrant
sudo: passwordless
os: Ubuntu 26.04.1 LTS
disk: 19G root filesystem
```

`make add` replaces any box already added as `local/ubuntu-26.04` for this provider.

## How the build works

### The template

`ubuntu.pkr.hcl` has four parts:

| Block | Does |
| --- | --- |
| `packer` | Names the plugins the template needs: `virtualbox` for the builder, `vagrant` for the post-processor. `packer init` installs them. |
| `variable` | Values the Makefile passes with `-var`: the OVF path, the box file and Vagrant's key |
| `source "virtualbox-ovf" "ubuntu"` | How to start the VM: which OVF to import, the cloud-init seed, and how to log in |
| `build` | Starts the source, runs the provisioner in it, then the post-processor on the result |

The Makefile passes the values that depend on your Mac, such as where Vagrant is
installed, so the template has nothing machine-specific in it. Run `make box` rather
than `packer build`, or pass the same `-var` options yourself.

### Step 1: wrap the cloud image in an OVF

Packer's VirtualBox builders either install an OS from an ISO (`virtualbox-iso`) or
import an existing VM (`virtualbox-ovf`). Neither reads a qcow2 disk, so `make ovf`
makes a VM for Packer to import:

1. `VBoxManage clonemedium` copies the cloud image to a VDI disk. VirtualBox reads qcow2
   directly, so no converter is needed. `modifymedium --resize` grows the disk to 20 GB.
2. `VBoxManage createvm` and `modifyvm` create an Arm VM with UEFI firmware, a virtio
   network card on NAT, and the disk on a SATA controller named `SATA`.
3. `VBoxManage export` writes the VM as `.build/ovf/ubuntu-26.04.ovf` with its disk, and
   the VM is deleted.

### Step 2: import the OVF and let cloud-init create the vagrant user

The `virtualbox-ovf` source imports the OVF as a new VM and boots it.

Cloud images run cloud-init at first boot. It looks for configuration from the cloud.
On a local VM, that configuration comes from a small ISO labelled `cidata`, a NoCloud
seed. Packer builds that ISO from `cd_files` and attaches it as a DVD:

```hcl
cd_files                  = ["${path.root}/cloud-init/user-data", "${path.root}/cloud-init/meta-data"]
cd_label                  = "cidata"
guest_additions_interface = "sata"
```

By default, Packer attaches its ISOs to a controller named `IDE`, but Arm VMs in
VirtualBox have no IDE controller. `guest_additions_interface = "sata"` makes it use the
controller named `SATA` instead, which is why step 1 gives the controller that name.
Despite its name, the setting covers all the ISOs Packer attaches, not only the Guest
Additions.

The user data creates `vagrant` with Vagrant's insecure public keys. Those keys are
published on purpose: the matching private keys ship with Vagrant, which is how Vagrant
gets into any new box. Packer logs in with the same private key, so it waits for SSH
until cloud-init has created the user. When a VM is later made from the box, Vagrant
swaps the insecure key for a new key pair.

Two more settings keep the image as it is: `guest_additions_mode = "disable"` leaves out
the VirtualBox Guest Additions, and `virtualbox_version_file = ""` stops Packer writing
`~/.vbox_version` into the VM.

### Step 3: clean up

The `shell` provisioner runs `scripts/cleanup.sh` with `sudo`. It waits for cloud-init,
then removes what ties the disk to this one VM:

- cloud-init wrote a netplan file that only matches the build VM's MAC address. The
  script swaps it for one that runs DHCP on any `en*` interface, and tells cloud-init not
  to write network config again.
- `cloud-init clean --machine-id` clears cloud-init's record of this boot and the
  machine ID, so each VM made from the box gets its own.
- It removes apt's cache and lists, temporary files and shell history, then runs
  `fstrim` so the free space doesn't end up in the box.

Packer then shuts the VM down with `shutdown_command`, exports it to `.build/packer/`
and deletes it from VirtualBox.

### Step 4: package the box

The `vagrant` post-processor packages the export as a box for the `virtualbox` provider,
writes it to `output/` and deletes the export. The box holds:

| File | Contents |
| --- | --- |
| `box.ovf` | The VM's settings: CPU, memory, firmware, controllers, network card |
| `ubuntu-26.04-disk001.vmdk` | The disk |
| `ubuntu-26.04.nvram` | The VM's UEFI variables |
| `metadata.json` | `{"architecture":"arm64","provider":"virtualbox"}` |
| `Vagrantfile` | The network card's MAC address |

### Step 5: add and use the box

`make add` runs `vagrant box add` with the box file. From then on, any project can use
it by name, as `test/Vagrantfile` does:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "local/ubuntu-26.04"

  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |vb|
    vb.check_guest_additions = false
  end
end
```

The box has no Guest Additions, so projects that use it turn off the default `/vagrant`
folder and the Guest Additions check. To share a folder, use `type: "rsync"`. Projects
that install packages should run `apt-get update` first, since the cleanup removed apt's
lists.

## Changing the box

- **Disk size**: `make all DISK_SIZE_MB=40960`, after `make clean` so the OVF is rebuilt.
- **CPUs or memory**: add a `vboxmanage` option to the source, such as
  `vboxmanage = [["modifyvm", "{{ .Name }}", "--cpus", "4"]]`.
- **Software in the box**: add `packages:` or `runcmd:` to `cloud-init/user-data`, or
  another `shell` provisioner before the cleanup.
- **Box name or file**: `make all BOX_NAME=me/ubuntu BOX_FILE=output/me.box`.

## Troubleshooting

- **`Could not find a controller named 'IDE'` or `'SATA'`**: the OVF's controller isn't
  named `SATA`, or `guest_additions_interface` isn't `"sata"`. Run `make clean` to
  rebuild the OVF.
- **The build stops at `Waiting for SSH to become available`**: cloud-init didn't create
  the `vagrant` user. Set `headless = false` in the source to watch the console.
- **`Error: Missing plugins`**: run `make init`.
- **`make box` says the box is up to date**: it only rebuilds when the OVF, template,
  cloud-init files or cleanup script has changed. Run `make clean` first to force a
  rebuild.
