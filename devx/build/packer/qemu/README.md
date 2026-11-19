# Building a Vagrant box for QEMU with Packer on macOS

This project uses [Packer](https://developer.hashicorp.com/packer) to turn Ubuntu's
official 26.04 cloud image into a Vagrant box for the
[vagrant-qemu](https://github.com/ppggff/vagrant-qemu) provider. Packer boots the cloud
image in QEMU, cloud-init adds the user Vagrant needs, a script cleans up, and Packer's
Vagrant post-processor packages the disk as a box. The box is named
`local/ubuntu-26.04`.

It's a small, single-purpose example of how Packer builds an image: one source, one
build block, one provisioner and one post-processor.

## Requirements

- macOS on Apple Silicon
- [Packer](https://developer.hashicorp.com/packer) 1.10 or newer
- [QEMU](https://www.qemu.org/)
- [Vagrant](https://developer.hashicorp.com/vagrant) and the `vagrant-qemu` plugin, to
  add and test the box. Packer also logs into the build VM with Vagrant's insecure
  key, which comes with Vagrant.

Install them with Homebrew and Vagrant:

```bash
brew install hashicorp/tap/packer qemu
brew install --cask vagrant
vagrant plugin install vagrant-qemu
```

Install Packer from HashiCorp's tap: Homebrew's own `packer` formula stopped at 1.9.4.

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `ubuntu.pkr.hcl` | The Packer template: the plugins, variables, QEMU source and build |
| `cloud-init/user-data` | Creates the `vagrant` user with passwordless sudo and Vagrant's insecure public keys |
| `cloud-init/meta-data` | The instance ID and hostname cloud-init expects in a seed |
| `scripts/cleanup.sh` | Runs in the build VM before packaging and removes state tied to that one VM |
| `test/Vagrantfile` | An ordinary Vagrant project that uses the finished box |
| `Makefile` | The build steps and short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

The Makefile downloads the cloud image to `images/` and writes the box to `output/`.
Packer works in `.build/` while it builds.

## Usage

| Make | mise | Does |
| --- | --- | --- |
| `make all` | `mise run all` | `box`, `add` and `test`, in that order |
| `make image` | `mise run image` | Downloads the cloud image and checks its SHA-256 checksum |
| `make init` | `mise run init` | `packer init`, installing the QEMU and Vagrant plugins |
| `make validate` | `mise run validate` | `packer validate`, checking the template |
| `make box` | `mise run box` | `packer build`, writing `output/ubuntu-26.04-qemu.box` |
| `make add` | `mise run add` | `vagrant box add`, naming the box `local/ubuntu-26.04` |
| `make test` | `mise run test` | Starts a VM from the added box, then runs `verify` |
| `make verify` | `mise run verify` | Prints the test VM's user, sudo access, OS and disk size |
| `make ssh` | `mise run ssh` | `vagrant ssh` into the test VM |
| `make destroy` | `mise run destroy` | Deletes the test VM |
| `make clean` | `mise run clean` | `destroy`, then deletes the box file and Packer's work directory |
| `make purge` | `mise run purge` | `clean`, then removes the added box, the downloaded image and Packer's cache |

Build the box, add it and try it:

```bash
make all
```

The first run downloads the cloud image, about 900 MB. After that, `make box` takes
under a minute. A successful test ends like this:

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
| `packer` | Names the plugins the template needs: `qemu` for the builder, `vagrant` for the post-processor. `packer init` installs them. |
| `variable` | Values the Makefile passes with `-var`: the image path, the checksum URL, the box file, Vagrant's key and QEMU's firmware directory |
| `source "qemu" "ubuntu"` | How to start the VM: which disk, which firmware, how much CPU and memory, the cloud-init seed, and how to log in |
| `build` | Starts the source, runs the provisioner in it, then the post-processor on the result |

The Makefile passes the values that depend on your Mac, such as where Vagrant and QEMU
are installed, so the template has nothing machine-specific in it. Run `make box`
rather than `packer build`, or pass the same `-var` options yourself.

### Step 1: boot the cloud image

Packer's QEMU builder usually installs an OS from an ISO. With `disk_image = true`, it
treats `iso_url` as a ready-made disk instead: it copies the cloud image into `.build/`
and grows the copy to `disk_size`, 20 GB. The downloaded file never changes.

Packer checks the image against Ubuntu's `SHA256SUMS` file before it boots, through
`iso_checksum = "file:…"`. The Makefile checks it too when it downloads it, so a bad
download never reaches Packer.

The VM is an Arm VM on Apple's Hypervisor framework (`accelerator = "hvf"`), booting
with the UEFI firmware that comes with QEMU.

### Step 2: let cloud-init create the vagrant user

Cloud images run cloud-init at first boot. It looks for configuration from the cloud.
On a local VM, that configuration comes from a small ISO labelled `cidata`, a NoCloud
seed. Packer builds that ISO from `cd_files` and attaches it to the VM:

```hcl
cd_files = ["${path.root}/cloud-init/user-data", "${path.root}/cloud-init/meta-data"]
cd_label = "cidata"
```

The user data creates `vagrant` with Vagrant's insecure public keys. Those keys are
published on purpose: the matching private keys ship with Vagrant, which is how Vagrant
gets into any new box. Packer logs in with the same private key, so it waits for SSH
until cloud-init has created the user. When a VM is later made from the box, Vagrant
swaps the insecure key for a new key pair.

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

Packer then shuts the VM down with `shutdown_command`.

### Step 4: package the box

The `vagrant` post-processor packages the qcow2 disk as a box for the `libvirt`
provider, which is the box format vagrant-qemu reads. It writes the box to `output/` and
deletes the disk in `.build/`. The box holds:

| File | Contents |
| --- | --- |
| `box_0.img` | The disk, in qcow2 format |
| `metadata.json` | `{"architecture":"arm64","disks":[{"format":"qcow2","path":"box_0.img"}],"provider":"libvirt"}` |
| `Vagrantfile` | A `libvirt` provider block, which vagrant-qemu ignores |

### Step 5: add and use the box

`make add` runs `vagrant box add` with the box file. From then on, any project can use
it by name, as `test/Vagrantfile` does:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "local/ubuntu-26.04"
end
```

The box has no extra software for synced folders, so the test project turns off the
default `/vagrant` folder. To share a folder, use `type: "rsync"`. Projects that install
packages should run `apt-get update` first, since the cleanup removed apt's lists.

## Changing the box

- **Disk size, CPUs or memory**: `disk_size`, `cpus` and `memory` in the source.
- **Software in the box**: add `packages:` or `runcmd:` to `cloud-init/user-data`, or
  another `shell` provisioner before the cleanup.
- **Box name or file**: `make all BOX_NAME=me/ubuntu BOX_FILE=output/me.box`.

## Troubleshooting

- **The build stops at `Waiting for SSH to become available`**: cloud-init didn't create
  the `vagrant` user. Packer prints a VNC address when it starts the VM; open it in a VNC
  viewer to watch the console.
- **`Error: Missing plugins`**: run `make init`.
- **`make box` says the box is up to date**: it only rebuilds when the image, template,
  cloud-init files or cleanup script has changed. Run `make clean` first to force a
  rebuild.
