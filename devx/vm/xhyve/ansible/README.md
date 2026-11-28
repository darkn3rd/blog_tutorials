# xhyve and Ansible on Intel Macs

This project runs an Ubuntu 26.04 virtual machine with [xhyve](https://github.com/machyve/xhyve),
a small hypervisor for Intel Macs, and configures it with Ansible. A Makefile drives every
step: building and signing xhyve, downloading the image, creating the disk, building the
cloud-init seed, booting the VM and shutting it down. The playbook sets up a small web server
so there is something to see once the VM is configured.

xhyve is a minimal project whose last commit was in October 2021. Read
[Things to know](#things-to-know) before you rely on it.

## Requirements

- **An Intel Mac.** xhyve runs x86-64 guests on the Hypervisor framework, so it doesn't run
  on Apple Silicon. It was tested on macOS 26.6.2 with an Intel Core i5-1038NG7.
- **The Command Line Tools**, for `git`, `make`, the compiler and `codesign`:
  `xcode-select --install`. Full Xcode isn't needed.
- **`sudo`.** xhyve needs root to create its network interface (see below).
- [QEMU](https://www.qemu.org/), only for `qemu-img`, which converts the image to the raw
  format xhyve reads
- [Ansible](https://docs.ansible.com/)

Install the last two with Homebrew:

```bash
brew install qemu ansible
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

xhyve itself isn't in Homebrew. The Makefile clones, builds and signs it for you the first
time you run `make up`.

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Builds xhyve, downloads the image, creates the disk and seed, starts and stops the VM |
| `hypervisor.entitlements` | The one entitlement xhyve is signed with, so macOS lets it use the Hypervisor framework |
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
| `make up` | `mise run up` | Build xhyve, create or start the VM and wait for it, without the playbook |
| `make up PROVISION=true` | `PROVISION=true mise run up` | The same, then run the playbook |
| `make provision` | `mise run provision` | `ansible-playbook playbook.yaml` |
| `make verify` | `mise run verify` | `curl` the web page |
| `make url` | `mise run url` | Print the web page's address |
| `make ssh` | `mise run ssh` | SSH into the VM |
| `make status` | `mise run status` | Report running, stopped or not created, and the VM's address |
| `make halt` | `mise run halt` | Shut the guest down, stopping xhyve if it ignores the request for 60s |
| `make reload` | `mise run reload` | `make halt`, then `make up` |
| `make destroy` | `mise run destroy` | Stop xhyve and delete `.vm/`, keeping the downloaded files and the xhyve build |
| `make purge` | `mise run purge` | Delete the downloaded files and the xhyve build |

The first `make up` builds xhyve, which takes about a minute, and downloads the Ubuntu cloud
image, about 820 MB, plus its kernel and initrd, about 90 MB, into `images/`. It asks for your
password once, when it starts the VM.

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
| Get xhyve | Clone it, check out a pinned commit, build it with `make` and sign it with `codesign` |
| Get the image | `curl`, then check it against Ubuntu's `SHA256SUMS` |
| Get the kernel and initrd | The same, from the image's `unpacked/` folder, because xhyve boots a kernel directly |
| Create the disk | `qemu-img` converts the image to raw and grows it to 20 GiB |
| Set up the guest user | A generated SSH key and a cloud-init seed ISO made with `hdiutil` |
| Boot | `sudo xhyve`, with the kernel and initrd, a virtio disk and network card, and the seed ISO |
| Find the VM | Read its address from macOS's DHCP lease file, by the hostname `dev` |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |
| Track the VM state | xhyve's PID file |
| Shut down | `poweroff` over SSH, then `kill` if xhyve is still running |

## Changing the configuration

Edit `site/index.html`, then run:

```bash
make provision
```

Ansible copies the new page into the VM. Because the file changed, the task notifies the
`Reload nginx` handler, which reloads the web server. Run `make provision` again without
changes and Ansible reports `changed=0`, and the handler doesn't run.

## Things to know

- **xhyve is pinned to an older commit on purpose.** Its newest commit, from October 2021,
  replaced the timer code with libdispatch. With that commit the guest froze, with xhyve idle,
  in every run on the test Mac, at different points in the boot. The commit before it booted
  and ran through all the tests below. The Makefile pins that one with `XHYVE_REF`. One
  earlier diagnostic run on it also froze, about 90 seconds in, while packet captures were
  scrolling past on the console, and its cause wasn't found. The theory behind the freeze is a
  guess: a timer interrupt that never wakes the guest.
- **xhyve has to be signed.** An unsigned build fails with `hv_vm_create unknown error
  -85377017`, which is `0xfae94007`, "denied". Signing with
  `com.apple.security.hypervisor` fixes that. It's an ad-hoc signature, so nothing is
  uploaded or notarized.
- **xhyve has to run as root.** Its network card uses macOS's vmnet framework, and xhyve's
  README says that needs root or an Apple-granted entitlement. The Makefile runs xhyve, and
  the `kill` that stops it, with `sudo`, and nothing else, so your files stay yours.
- **The build uses `CFLAGS_WARN=-w`.** xhyve's own build treats warnings as errors, and
  today's compiler produces some from its 2021 code.
- **The kernel boots with `tsc=reliable`.** That was part of the configuration that worked.
  Whether xhyve needs it with the pinned commit wasn't tested on its own.
- **There's no shared folder.** xhyve has no 9p or virtio-fs device, so the project folder
  isn't mounted in the VM.
- **The VM's address changes between boots and old leases pile up.** The guest asks for an
  address twice, once in the initrd and once after boot, and macOS keeps old leases in
  `/var/db/dhcpd_leases`. The Makefile picks the newest lease for the hostname `dev`, and
  looks it up when each command runs, because `make` expands a whole recipe before running
  any of it.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.
- **`.vm/` holds the VM's private SSH key.** It only opens this VM, which is reachable only
  from your Mac.

## Cleaning up

```bash
make destroy
make purge
```

`make destroy` deletes the VM. `make purge` also deletes the downloaded files and the xhyve
build, so the next `make up` fetches and builds them again.

## Troubleshooting

### `No route to host` when connecting to the VM

If `ping` or `ssh` to the VM's address fails with `No route to host` while the guest is
running, check whether it works as root:

```bash
sudo ping -c 3 "$(make -s url | sed 's|http://||')"
```

On the test Mac, root could reach the VM and a normal user couldn't, until **Local Network**
access was turned on for the terminal app in System Settings, Privacy & Security, Local
Network, and the app was restarted. That setting is the likely cause, but it wasn't
isolated from the restart.

### SSH doesn't come up

Look at the guest's console:

```bash
tail -50 .vm/console.log
```

If it stops partway through the boot and `make status` still says `running`, the guest has
frozen. Run `make destroy up`. If it keeps happening, check that `XHYVE_REF` is still the
pinned commit.

If the log is nearly empty, xhyve probably didn't start, and its own error is in that log.
`Failed to set up pidfile` means `.vm/xhyve.pid` already existed, which xhyve refuses. The
Makefile removes a stale one before starting.

### Waiting for SSH takes minutes, or `make up` picks the wrong address

macOS keeps old leases for the hostname `dev`. The Makefile takes the newest, so a stale one
only wastes a few attempts. If you still hit it, check the leases:

```bash
grep -B1 -A4 'name=dev' /var/db/dhcpd_leases
```

## Tested

On macOS 26.6.2, an Intel Core i5-1038NG7, Ubuntu 26.04.1, xhyve at the pinned commit,
Ansible core 2.21, `qemu-img` 11.0.1:

- Building and signing xhyve, and downloading and checking the image, kernel and initrd
- A fresh `make up PROVISION=true`, which took 83 seconds once the downloads were cached,
  with the page returning `200 OK` and the guest disk grown to 19 GB
- `make provision` a second time, which reported `changed=0`
- `make halt`, which took 3 seconds, `make up` from a stopped VM, and `make reload`
- `make destroy`, which left no xhyve process behind
- `mise run deps` and `mise run versions`

Not tested: `make ssh`, `make purge`, the `halt` fallback that kills xhyve, changing
`CPUS`, `MEMORY` or `DISK_SIZE`, a different subnet, and any Mac other than the one above.
The timings are from single runs.
