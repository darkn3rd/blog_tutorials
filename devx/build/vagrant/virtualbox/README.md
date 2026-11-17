# Building a Vagrant box for VirtualBox on macOS

This project turns Ubuntu's official 26.04 cloud image into a Vagrant box for
VirtualBox, Vagrant's default provider. It uses only Vagrant and VirtualBox. There's no
separate image-building tool: VirtualBox reads the cloud image, `vagrant package` wraps
it in a box, cloud-init adds the user Vagrant needs, and `vagrant package` saves the
result as the finished box.

## Requirements

- macOS on Apple Silicon
- [Vagrant](https://developer.hashicorp.com/vagrant)
- [VirtualBox](https://www.virtualbox.org/) 7.1 or newer, the first release that
  officially supports Apple Silicon Macs

Install them with Homebrew:

```bash
brew install --cask vagrant virtualbox
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Vagrantfile` | The build VM: starts from the base box, passes cloud-init its user data, runs the cleanup script |
| `cloud-init/user-data` | Creates the `vagrant` user with passwordless sudo and Vagrant's insecure public keys |
| `scripts/cleanup.sh` | Runs in the build VM before packaging and removes state tied to that one VM |
| `test/Vagrantfile` | An ordinary project that uses the finished box |
| `Makefile` | The build steps and short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

The Makefile downloads the cloud image to `images/`, keeps the base box in `.build/` and
writes the finished box to `output/`.

## Usage

| Make | mise | Does |
| --- | --- | --- |
| `make all` | `mise run all` | `build`, `add` and `test`, in that order |
| `make image` | `mise run image` | Downloads the cloud image and checks its SHA-256 checksum |
| `make base` | `mise run base` | Builds the base box, `.build/ubuntu-26.04-base.box` |
| `make build` | `mise run build` | Builds `output/ubuntu-26.04-virtualbox.box`, starting with `base` |
| `make add` | `mise run add` | `vagrant box add`, naming the box `local/ubuntu-26.04` |
| `make test` | `mise run test` | Starts a VM from the added box, then runs `verify` |
| `make verify` | `mise run verify` | Prints the test VM's user, sudo access, OS and disk size |
| `make ssh` | `mise run ssh` | `vagrant ssh` into the test VM |
| `make destroy` | `mise run destroy` | Deletes the build and test VMs |
| `make clean` | `mise run clean` | `destroy`, then deletes the base box and the box file |
| `make purge` | `mise run purge` | `clean`, then removes the added box and the downloaded image |

Build the box, add it and try it:

```bash
make all
```

The first run downloads the cloud image, about 900 MB. After that, a build takes about
four minutes. A successful test ends like this:

```text
user: vagrant
sudo: passwordless
os: Ubuntu 26.04.1 LTS
disk: 19G root filesystem
```

## How the build works

### What a box is

A box is a tar archive. For VirtualBox it holds an exported VM plus two small files:

| File | Contents |
| --- | --- |
| `box.ovf` | The VM's settings: CPU, memory, firmware, controllers, network card |
| `*.vmdk` | The VM's disk |
| `*.nvram` | The VM's UEFI variables |
| `metadata.json` | `{"provider":"virtualbox"}` |
| `Vagrantfile` | Defaults for VMs made from the box; here, the network card's MAC address |

Ubuntu's cloud image is a qcow2 disk, with no VM settings around it and no `vagrant`
user inside. The build adds both, in two passes.

### Step 1: wrap the cloud image in a base box

Vagrant's VirtualBox provider can only start a VM from a box, so the first pass makes
one. Instead of writing `box.ovf` by hand, the Makefile creates a VirtualBox VM around
the disk and lets Vagrant export it:

1. `VBoxManage clonemedium` copies the cloud image to a VDI disk. VirtualBox reads qcow2
   directly, so no converter is needed. `modifymedium --resize` grows the disk to 20 GB.
2. `VBoxManage createvm` and `modifyvm` create an ARM VM with UEFI firmware, a virtio
   network card on NAT, and the disk on a SATA controller.
3. `vagrant package --base ubuntu-26.04-base` exports that VM as a box. `--base` packages
   a VirtualBox VM that Vagrant didn't create.
4. The VM is deleted. Only the base box file is left.

The base box boots, but Vagrant can't log in yet.

### Step 2: let cloud-init create the vagrant user

The second pass adds the base box as `local/ubuntu-26.04-base` and starts a VM from it
with the `Vagrantfile`.

Cloud images run cloud-init at first boot. It looks for configuration from the cloud.
On a local VM, that configuration comes from a small ISO labelled `cidata`, a NoCloud
seed. Vagrant builds that ISO for you from the `config.vm.cloud_init` setting and
attaches it as a DVD:

```ruby
config.vm.cloud_init :user_data,
  content_type: "text/cloud-config",
  path: "cloud-init/user-data"
```

The user data creates `vagrant` with Vagrant's insecure public keys. Those keys are
published on purpose: the matching private keys ship with Vagrant, which is how Vagrant
gets into any new box. When a VM is made from the box, Vagrant swaps the insecure key
for a new key pair (the test run shows this as `Inserting generated public key`).

`cloud_init` is still an experimental Vagrant feature and depends on the experimental
`disks` feature. The Makefile turns both on for the build only:

```bash
VAGRANT_EXPERIMENTAL=cloud_init,disks vagrant up --provider=virtualbox
```

Three settings in the `Vagrantfile` keep the build working with a bare cloud image:

- `config.ssh.insert_key = false` keeps the insecure key in the build VM. Otherwise
  Vagrant would replace it, and `vagrant package` would put the new private key in the
  box.
- The default `/vagrant` synced folder is turned off. It needs the VirtualBox Guest
  Additions, which the cloud image doesn't have.
- `vb.check_guest_additions = false` stops Vagrant from looking for them.

### Step 3: clean up

The shell provisioner runs `scripts/cleanup.sh` as root. It waits for cloud-init, then
removes what ties the disk to this one VM:

- cloud-init wrote a netplan file that only matches the build VM's MAC address. The
  script swaps it for one that runs DHCP on any `en*` interface, and tells cloud-init not
  to write network config again.
- `cloud-init clean --machine-id` clears cloud-init's record of this boot and the
  machine ID, so each VM made from the box gets its own.
- It removes apt's cache and lists, temporary files and shell history, then runs
  `fstrim` so the free space doesn't end up in the box.

### Step 4: package the VM

`vagrant package --output output/ubuntu-26.04-virtualbox.box` shuts the VM down, exports
it, and writes `metadata.json` and the box's `Vagrantfile`. The seed ISO isn't included;
the exported VM keeps an empty DVD drive. The Makefile then deletes the build VM and
removes the base box from Vagrant.

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
folder. To share a folder, use `type: "rsync"`, or install the Guest Additions in the box
from `scripts/cleanup.sh`.

## Changing the box

- **Disk size**: `make all DISK_SIZE_MB=40960`. The base box is only rebuilt after
  `make clean`.
- **Software in the box**: add `packages:` or `runcmd:` to `cloud-init/user-data`, or
  commands to `scripts/cleanup.sh` before the cleanup.
- **Box name or file**: `make all BOX_NAME=me/ubuntu BOX_FILE=output/me.box`.

## Troubleshooting

- **The build stops at `Waiting for machine to boot`**: cloud-init didn't create the
  `vagrant` user. Check that `VAGRANT_EXPERIMENTAL` includes both `cloud_init` and
  `disks`; without them, Vagrant ignores the `cloud_init` setting and doesn't attach the
  seed.
- **`make build` says the box is up to date**: it only rebuilds when the image,
  `Vagrantfile`, user data or cleanup script has changed. Run `make clean` first to force
  a rebuild.
