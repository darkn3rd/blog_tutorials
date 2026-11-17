# Building a Vagrant box for QEMU on macOS

This project turns Ubuntu's official 26.04 cloud image into a Vagrant box for the
[vagrant-qemu](https://github.com/ppggff/vagrant-qemu) provider. It uses only Vagrant,
the plugin and QEMU. There's no separate image-building tool: Vagrant boots the cloud
image, cloud-init adds the user Vagrant needs, and `vagrant package` saves the result
as a box.

## Requirements

- macOS on Apple Silicon
- [Vagrant](https://developer.hashicorp.com/vagrant)
- [QEMU](https://www.qemu.org/)
- The `vagrant-qemu` plugin, version 0.7.0 or newer. This project was tested with
  0.7.0, which supports `vagrant package` and Vagrant's `cloud_init` setting. Older
  releases may not.

Install them with Homebrew and Vagrant:

```bash
brew install --cask vagrant
brew install qemu
vagrant plugin install vagrant-qemu
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Vagrantfile` | The build VM: boots the cloud image, passes cloud-init its user data, runs the cleanup script |
| `cloud-init/user-data` | Creates the `vagrant` user with passwordless sudo and Vagrant's insecure public keys |
| `scripts/cleanup.sh` | Runs in the build VM before packaging and removes state tied to that one VM |
| `test/Vagrantfile` | An ordinary project that uses the finished box |
| `Makefile` | The build steps and short commands for the steps below |
| `mise.toml` | The same commands as mise tasks, plus `deps` and `versions` |

The Makefile downloads the cloud image to `images/` and writes the box to `output/`.

## Usage

| Make | mise | Does |
| --- | --- | --- |
| `make all` | `mise run all` | `build`, `add` and `test`, in that order |
| `make image` | `mise run image` | Downloads the cloud image and checks its SHA-256 checksum |
| `make build` | `mise run build` | Builds `output/ubuntu-26.04-qemu.box` |
| `make add` | `mise run add` | `vagrant box add`, naming the box `local/ubuntu-26.04` |
| `make test` | `mise run test` | Starts a VM from the added box, then runs `verify` |
| `make verify` | `mise run verify` | Prints the test VM's user, sudo access, OS and disk size |
| `make ssh` | `mise run ssh` | `vagrant ssh` into the test VM |
| `make destroy` | `mise run destroy` | Deletes the build and test VMs |
| `make clean` | `mise run clean` | `destroy`, then deletes the box file |
| `make purge` | `mise run purge` | `clean`, then removes the added box and the downloaded image |

Build the box, add it and try it:

```bash
make all
```

The first run downloads the cloud image, about 900 MB. After that, a build takes a few
minutes. A successful test ends like this:

```text
user: vagrant
sudo: passwordless
os: Ubuntu 26.04.1 LTS
disk: 19G root filesystem
```

## How the build works

### What a box is

A box is a tar archive. For vagrant-qemu it holds three files:

| File | Contents |
| --- | --- |
| `box.img` | The VM's disk, in qcow2 format |
| `metadata.json` | `{"provider": "libvirt", "format": "qcow2", "virtual_size": 20}` |
| `Vagrantfile` | Defaults for VMs made from the box; here, just the CPU architecture |

vagrant-qemu reads the box format of the vagrant-libvirt provider, so the metadata says
`libvirt`, and `vagrant box list` shows the box with that provider.

Ubuntu's cloud image is already a qcow2 disk. What it lacks is what Vagrant expects
inside the guest: a `vagrant` user that it can log into with its insecure key and that
can run `sudo` without a password.

### Step 1: boot the cloud image without a box

vagrant-qemu can start a VM from a disk image instead of a box. The `Vagrantfile` sets
`image_path` to the downloaded image and leaves out `config.vm.box`. vagrant-qemu
creates a copy-on-write overlay on top of the image, grown to 20 GB by `disk_resize`,
so the downloaded file never changes.

### Step 2: let cloud-init create the vagrant user

Cloud images run cloud-init at first boot. It looks for configuration from the cloud.
On a local VM, that configuration comes from a small ISO labelled `cidata`, a NoCloud
seed. Vagrant builds that ISO for you from the `config.vm.cloud_init` setting and
attaches it to the VM:

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
VAGRANT_EXPERIMENTAL=cloud_init,disks vagrant up --provider=qemu
```

Two settings in the `Vagrantfile` keep the build working with a bare cloud image:

- `config.ssh.insert_key = false` keeps the insecure key in the build VM. Otherwise
  Vagrant would replace it, and `vagrant package` would put the new private key in the
  box.
- The default `/vagrant` synced folder is turned off, since the build doesn't need it.

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

### Step 4: package the disk

`vagrant package --output output/ubuntu-26.04-qemu.box` stops the VM, merges the overlay
and the cloud image into a standalone qcow2 `box.img`, and writes `metadata.json` and the
box's `Vagrantfile`. The seed ISO isn't included. The Makefile then deletes the build VM.

### Step 5: add and use the box

`make add` runs `vagrant box add` with the box file. From then on, any project can use
it by name, as `test/Vagrantfile` does:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "local/ubuntu-26.04"
end
```

The box has no extra software for synced folders, so the test project turns off the
default `/vagrant` folder. To share a folder, use `type: "rsync"`, or install the
software for another type in the box from `scripts/cleanup.sh`.

## Changing the box

- **Disk size**: `qe.disk_resize` in the `Vagrantfile`.
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
