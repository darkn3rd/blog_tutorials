# HyperKit and Ansible on Intel Macs

This project runs an Ubuntu 26.04 virtual machine with
[HyperKit](https://github.com/moby/hyperkit), a small hypervisor for Intel Macs, and
configures it with Ansible. A Makefile drives every step: building HyperKit, downloading the
image, creating the disk, building the cloud-init seed, booting the VM and shutting it down.
The playbook sets up a small web server so there is something to see once the VM is
configured.

HyperKit is built on Apple's Hypervisor framework and is based on xhyve and bhyve. Its last
commit was in February 2022. Read [Things to know](#things-to-know) before you rely on it.

## Requirements

- **An Intel Mac.** HyperKit runs x86-64 guests on the Hypervisor framework, so it doesn't run
  on Apple Silicon. It was tested on macOS 26.6.2 with an Intel Core i5-1038NG7.
- **The Command Line Tools**, for `git`, `make` and the compiler: `xcode-select --install`.
  Full Xcode isn't needed.
- **`sudo`.** The Makefile runs HyperKit as root (see below).
- [QEMU](https://www.qemu.org/), only for `qemu-img`, which converts the image to the raw
  format HyperKit reads
- [Ansible](https://docs.ansible.com/)

Install the last two with Homebrew:

```bash
brew install qemu ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

HyperKit itself isn't in Homebrew. The Makefile clones and builds it for you the first time
you run `make up`. HyperKit's own build can also use OCaml to read qcow2 disks, but the plain
build used here doesn't need it.

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Builds HyperKit, downloads the image, creates the disk and seed, starts and stops the VM |
| `cloud-init/` | The guest's first-boot settings: user, SSH key and hostname |
| `playbook.yaml` | The Ansible playbook that configures the VM |
| `inventory.yaml` | Tells Ansible how to reach the VM, in the `web` group |
| `ansible.cfg` | Ansible settings |
| `site/` | The web page and web server config that the playbook copies into the VM |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM has 2 CPUs, 4 GiB of memory and a 20 GiB disk.

## Usage

| Make | mise | What it does |
| --- | --- | --- |
| `make up` | `mise run up` | Build HyperKit, create or start the VM and wait for it, without the playbook |
| `make up PROVISION=true` | `PROVISION=true mise run up` | The same, then run the playbook |
| `make provision` | `mise run provision` | `ansible-playbook playbook.yaml` |
| `make verify` | `mise run verify` | `curl` the web page |
| `make url` | `mise run url` | Print the web page's address |
| `make ssh` | `mise run ssh` | SSH into the VM |
| `make status` | `mise run status` | Report running, stopped or not created, and the VM's address |
| `make halt` | `mise run halt` | Shut the guest down, stopping HyperKit if it ignores the request for 60s |
| `make reload` | `mise run reload` | `make halt`, then `make up` |
| `make destroy` | `mise run destroy` | Stop HyperKit and delete `.vm/`, keeping the downloaded files and the HyperKit build |
| `make purge` | `mise run purge` | Delete the downloaded files and the HyperKit build |

The first `make up` builds HyperKit, which takes about a minute, and downloads the Ubuntu
cloud image, about 820 MB, plus its kernel and initrd, about 90 MB, into `images/`. It asks
for your password once, when it starts the VM.

Create the VM and configure it:

```bash
make up PROVISION=true
```

Then open the address that `make url` prints, or check it from the terminal:

```bash
make verify
```

The VM gets its own address from macOS, on a network that only your Mac can reach, so there's
no `localhost` port to use. The address was `192.168.2.x` on the test Mac and can differ on
yours.

`CPUS`, `MEMORY` and `DISK_SIZE` can be overridden, for example `make up CPUS=4`. They apply
when the VM is created, so run `make destroy` first to change an existing VM. Only the
defaults were tested.

## What the Makefile does

| Job | How |
| --- | --- |
| Get HyperKit | Clone it, check out a pinned commit and build it with `make`, which also signs it |
| Get the image | `curl`, then check it against Ubuntu's `SHA256SUMS` |
| Get the kernel and initrd | The same, from the image's `unpacked/` folder, because HyperKit boots a kernel directly |
| Create the disk | `qemu-img` converts the image to raw and grows it to 20 GiB |
| Set up the guest user | A generated SSH key and a cloud-init seed ISO made with `hdiutil` |
| Boot | `sudo hyperkit`, with the kernel and initrd, a virtio disk and network card, and the seed ISO |
| Find the VM | Read its address from macOS's DHCP lease file, by the hostname `dev` |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |
| Track the VM state | HyperKit's PID file |
| Shut down | `poweroff` over SSH, then `kill` if HyperKit is still running |

## Changing the configuration

Edit `site/index.html`, then run:

```bash
make provision
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

- **HyperKit has to run as root.** The Makefile runs it, and the `kill` that stops it, with
  `sudo`, and nothing else, so your files stay yours. It was only tested as root. HyperKit's
  network card uses macOS's vmnet framework, and its README doesn't say whether that works
  without root.
- **HyperKit signs itself.** Its build applies an ad-hoc signature with the
  `com.apple.security.hypervisor` entitlement, which macOS needs before it lets a program use
  the Hypervisor framework. Nothing is uploaded or notarized.
- **The build uses `CFLAGS_WARN=-w`.** HyperKit's own build treats warnings as errors, and
  today's compiler produces some from its older code.
- **There's no shared folder.** HyperKit's `virtio-9p` device only connects to a separate 9P
  server that you'd have to run, so the project folder isn't mounted in the VM.
- **The VM boots a kernel directly.** HyperKit's kexec loader takes a kernel and initrd, so
  the Makefile downloads Ubuntu's separate copies of both rather than booting the disk's own
  boot loader.
- **The VM's address changes between boots and old leases pile up.** The guest asks for an
  address twice, once in the initrd and once after boot, and macOS keeps old leases in
  `/var/db/dhcpd_leases`. The Makefile picks the newest lease for the hostname `dev`, and
  looks it up when each command runs, because `make` expands a whole recipe before running
  any of it.
- **HyperKit refuses an existing PID file,** and removes its own when it exits. The Makefile
  deletes a stale one before starting.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.
- **`.vm/` holds the VM's private SSH key.** It only opens this VM, which is reachable only
  from your Mac.

## Cleaning up

```bash
make destroy
make purge
```

`make destroy` deletes the VM. `make purge` also deletes the downloaded files and the
HyperKit build, so the next `make up` fetches and builds them again.

## Troubleshooting

### `No route to host` when connecting to the VM

If `ping` or `ssh` to the VM's address fails with `No route to host` while the guest is
running, check whether it works as root:

```bash
sudo ping -c 3 "$(make -s url | sed 's|http://||')"
```

On the test Mac, a program that wasn't running as root couldn't reach a VM on the vmnet
network until **Local Network** access was turned on for the terminal app in System
Settings, Privacy & Security, Local Network, and the app was restarted. That setting is the
likely cause, but it wasn't isolated from the restart.

### SSH doesn't come up

Look at the guest's console:

```bash
tail -50 .vm/console.log
```

If it stops partway through the boot and `make status` still says `running`, the guest has
frozen. Run `make destroy up`.

If the log is nearly empty, HyperKit probably didn't start, and its own error is in that log.

### Waiting for SSH takes minutes, or `make up` picks the wrong address

macOS keeps old leases for the hostname `dev`. The Makefile takes the newest, so a stale one
only wastes a few attempts. If you still hit it, check the leases:

```bash
grep -B1 -A4 'name=dev' /var/db/dhcpd_leases
```

## Tested

On macOS 26.6.2, an Intel Core i5-1038NG7, Ubuntu 26.04.1, HyperKit at the pinned commit,
Ansible core 2.21, `qemu-img` 11.0.1:

- Building HyperKit, which signs itself
- A fresh `make up PROVISION=true`, with the page returning `200 OK` and the guest disk grown
  to 19 GB
- `make provision` a second time, which reported `changed=0`
- The guest staying up through 3 minutes idle, with the page still served
- `make halt`, which took 3 seconds, `make up` from a stopped VM, which took 41 seconds
  including typing the password, and `make reload`, which took 20 seconds
- `make destroy`, which took 5 seconds and left no HyperKit process behind
- `mise run deps` and `mise run versions`

Not tested: the downloads, because the image, kernel and initrd were copied into `images/`
instead; `make ssh`; `make purge`; the `halt` fallback that kills HyperKit; running without
root; changing `CPUS`, `MEMORY` or `DISK_SIZE`; a longer
run than a few minutes; and any Mac other than the one above. The timings are from single
runs.
