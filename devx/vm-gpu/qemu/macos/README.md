# A GPU in a QEMU VM on macOS

This project runs a Fedora 45 virtual machine with QEMU on a Mac with Apple silicon, and
checks what the guest can do with a GPU. A Makefile drives every step: downloading the
image, creating the disk, building the cloud-init seed, starting QEMU, and benchmarking.
QEMU uses Apple's Hypervisor framework (`accel=hvf`), so the guest's CPU runs at native
speed.

| `GPU=` | What the guest gets | Guest APIs | Works with Homebrew's QEMU |
| --- | --- | --- | --- |
| `virtio` (default) | A 2D virtio-gpu: a display adapter without 3D | None on the GPU; OpenGL and Vulkan run on the CPU | Yes |
| `virgl` | A virtio-gpu that forwards OpenGL to the Mac's GPU | OpenGL | No |
| `venus` | A virtio-gpu that forwards Vulkan to the Mac's GPU | Vulkan | No |

Homebrew builds QEMU without OpenGL, so it only has the 2D virtio-gpu. With it, the
benchmark measures the CPU only, which is the point of comparison: this is what a Linux
VM on a Mac gets from QEMU out of the box. `make check` tells you whether the QEMU you
point it at can do `virgl` or `venus`.

There is no configuration step: cloud-init installs the drivers and build tools on first
boot, and `make bench` builds and runs the benchmark.

## Requirements

- A Mac with Apple silicon
- QEMU, from Homebrew, which includes the UEFI firmware

```bash
brew install qemu
```

Or, if you use [mise](https://mise.jdx.dev/), let it install it if it's missing:

```bash
mise run deps
```

For `virgl` and `venus`, a QEMU that has the `virtio-gpu-gl-pci` device. Installing
virglrenderer next to QEMU isn't enough: QEMU only has that device if it was compiled
with `--enable-opengl --enable-virglrenderer`. Upstream QEMU's virgl path is built on
Linux graphics APIs (EGL, GBM and DMA-BUF), which macOS doesn't have, so a macOS build
also needs ANGLE and libepoxy to turn OpenGL ES into Metal, plus patches that Homebrew's
formula doesn't carry. `venus` also needs virglrenderer 1.0 or later with Venus.

Two ways to get such a QEMU:

- **A community Homebrew tap** that patches QEMU and links it with ANGLE, libepoxy and
  virglrenderer, such as
  [startergo/homebrew-qemu-virgl-kosmickrisp](https://github.com/startergo/homebrew-qemu-virgl-kosmickrisp),
  [milesbuckton/homebrew-qemu-virgl](https://github.com/milesbuckton/homebrew-qemu-virgl),
  which also offers Venus, or the older
  [knazarov/homebrew-qemu-virgl](https://github.com/knazarov/homebrew-qemu-virgl). These
  aren't official; check that the one you pick is maintained for a current QEMU and your
  macOS version.
- **Building QEMU from source** with the same patches, ANGLE, libepoxy and virglrenderer.

Point the Makefile at the result with `QEMU=/path/to/qemu-system-aarch64`; `make check`
tells you whether it has the device. These two modes are not tested yet.

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Checks QEMU, downloads the image, creates the disk and seed, starts and stops QEMU, and runs the benchmark |
| `cloud-init/` | The guest's first-boot settings: user, SSH key, hostname, and the packages to install |
| `gpu-bench.sh` | Builds llama.cpp's `llama-bench` with Vulkan and runs it on the GPU and on the CPU |
| `hwinfo.sh` | Reports the virtual hardware the guest sees, GPU included, as Markdown or raw rows |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM has 2 CPUs, 4 GiB of memory and a 20 GiB disk. The project folder is copied into
the VM at `/workspace`.

## Usage

| make | What it does |
| --- | --- |
| `make check` | Check that this Mac and this QEMU can do what `GPU` asks for |
| `make up` | Check, download the image, create the VM, boot it, wait for cloud-init and copy the project in |
| `make gpu` | Show the GPUs, virtio-gpu features, and the Vulkan and OpenGL devices the guest sees |
| `make hwinfo` | Print a full report of the guest's virtual hardware: platform, firmware, CPU, video and GPU, OS and devices |
| `make bench` | Build `llama-bench` in the guest and run it, copying the results back to `results/` |
| `make ssh` | SSH in, starting in `/workspace` |
| `make status` | Report running, stopped or not created, and the GPU mode |
| `make halt` | Shut the guest down, stopping QEMU after 60s |
| `make reload` | `make halt`, then `make up` |
| `make destroy` | Stop QEMU and delete `.vm/`, keeping the downloaded image |
| `make purge` | Delete the downloaded image |

Each target also has a mise task, such as `mise run up`.

```bash
make up
make gpu
make bench
```

The GPU mode is chosen when the VM is created, so switching `GPU` needs `make destroy`
first. `CPUS`, `MEMORY` (MiB), `DISK_SIZE`, `SSH_PORT` (default 2222), `HOSTMEM`, `QEMU`,
`FEDORA_RELEASE` and `FEDORA_BUILD` can be overridden, for example `make up CPUS=4`.

## What the Makefile does

| Job | How |
| --- | --- |
| Get the image | `curl`, then check it against Fedora's `CHECKSUM` file |
| Create the disk | A qcow2 overlay on the cloud image with `qemu-img`, so it only uses space for what the guest writes |
| Firmware | Homebrew's `edk2-aarch64-code.fd`, read-only, and a copy of `edk2-arm-vars.fd` per VM for the UEFI variables |
| Set up the guest user | A generated SSH key and a cloud-init seed ISO made with `hdiutil` |
| Network | QEMU's user-mode network, with SSH forwarded from `127.0.0.1:2222` |
| Boot | `qemu-system-aarch64 -machine virt,accel=hvf -cpu host`, with virtio disks, network, RNG and the GPU for `GPU` |
| Know when it's ready | Poll SSH, then `cloud-init status --wait` |

## What the benchmark measures

`gpu-bench.sh` runs `llama-bench` with a small model, TinyLlama 1.1B, twice: with every
layer on the GPU, and on the CPU alone. It reports tokens per second for processing a
512-token prompt (`pp512`), which is mostly compute, and for generating 128 tokens
(`tg128`), which is mostly memory bandwidth. If Vulkan finds no GPU, as with `virtio`,
only the CPU run happens. It also records the OpenGL renderer, which is llvmpipe, Mesa's
software renderer, with `virtio`.

The results are appended to `results/<label>.csv`, with the full log next to it.

## Things to know

- **`make up` takes longer than a plain boot.** It waits for cloud-init, which installs
  the drivers and build tools with `dnf`.
- **`virgl` and `venus` open a window.** QEMU needs a display with OpenGL for them, and
  on macOS that is its Cocoa window, so QEMU runs as a background job instead of
  detaching.
- **Fedora lets only root read cloud-init's state,** so the Makefile runs
  `sudo cloud-init status --wait`.
- **Port 2222 must be free.** `make up` stops with a message if something else listens
  there; pick another port with `SSH_PORT=...` and pass it to every later command.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.

## Cleaning up

```bash
make destroy
make purge
```
