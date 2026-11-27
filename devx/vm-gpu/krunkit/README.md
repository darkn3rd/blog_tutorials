# A GPU in a krunkit VM on macOS

This project runs a Fedora 45 virtual machine with
[krunkit](https://github.com/containers/krunkit) and checks what the guest can do with
the Mac's GPU. A Makefile drives every step: downloading the image, creating the disk,
building the cloud-init seed, booting, and benchmarking.

krunkit runs the VM with libkrun on Apple's Hypervisor framework. It always gives the
guest a virtio-gpu device that forwards Vulkan to the Mac (Venus): the guest's Mesa
driver sends Vulkan commands over virtio-gpu, libkrun replays them with virglrenderer, and
MoltenVK turns them into Metal on the Mac's GPU. In the guest, Vulkan shows a device
named after the Mac's GPU, such as `Virtio-GPU Venus (Apple M1 Max)`.

There is no configuration step: cloud-init installs the Vulkan drivers and build tools
on first boot, and `make bench` builds and runs the benchmark.

## Requirements

- A Mac with Apple silicon
- krunkit, from Homebrew
- gvproxy, for the network; Homebrew's Podman includes it
- `qemu-img`, from Homebrew's `qemu`, to convert the image to raw once

```bash
brew install krunkit podman qemu
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Downloads the image, creates the disk and seed, starts and stops krunkit and gvproxy, and runs the benchmark |
| `cloud-init/` | The guest's first-boot settings: user, SSH key, hostname, `/workspace`, and the packages to install |
| `gpu-bench.sh` | Builds llama.cpp's `llama-bench` with Vulkan and runs it on the GPU and on the CPU |
| `hwinfo.sh` | Reports the virtual hardware the guest sees, GPU included, as Markdown or raw rows |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM has 2 CPUs, 4 GiB of memory and a 20 GiB disk. The project folder is shared with
the guest at `/workspace` over virtio-fs.

## Usage

| make | mise | What it does |
| --- | --- | --- |
| `make up` | `mise run up` | Download the image, create the VM, boot it and wait for cloud-init to install the packages |
| `make gpu` | `mise run gpu` | Show the virtio-gpu features and the Vulkan and OpenGL devices the guest sees |
| `make hwinfo` | `mise run hwinfo` | Print a full report of the guest's virtual hardware: platform, firmware, CPU, video and GPU, OS and devices |
| `make bench` | `mise run bench` | Build `llama-bench` in the guest and run it, saving the results to `results/` |
| `make ssh` | `mise run ssh` | SSH in, starting in `/workspace` |
| `make status` | `mise run status` | Report running, stopped or not created |
| `make halt` | `mise run halt` | Shut the guest down, then stop gvproxy |
| `make reload` | `mise run reload` | `make halt`, then `make up` |
| `make destroy` | `mise run destroy` | Stop krunkit and gvproxy and delete `.vm/`, keeping the downloaded image |
| `make purge` | `mise run purge` | Delete the downloaded image and its raw copy |

```bash
make up
make gpu
make bench
```

`make bench` takes several minutes the first time, mostly building llama.cpp's Vulkan
shaders on 2 vCPUs. Later runs reuse the build. Pin the llama.cpp release with
`make bench LLAMA_REF=b6000`, and name the run in the results with `LABEL`.

`SSH_PORT` (default 2222), `CPUS`, `MEMORY` and `DISK_SIZE` can be overridden, for
example `make up CPUS=4`. `FEDORA_RELEASE` and `FEDORA_BUILD` pick another Fedora Cloud
image, as named on Fedora's download site.

## What the benchmark measures

`gpu-bench.sh` runs `llama-bench` with a small model, TinyLlama 1.1B, twice: with every
layer on the GPU, and on the CPU alone. It reports tokens per second for processing a
512-token prompt (`pp512`), which is mostly compute, and for generating 128 tokens
(`tg128`), which is mostly memory bandwidth. If Vulkan finds no GPU, only the CPU run
happens, so there is always a baseline. It also records the OpenGL renderer.

The results are appended to `results/<label>.csv`, with the full log next to it.

## Why Fedora

Vulkan works in a Fedora 45 guest with Fedora's own Mesa, but not in an Ubuntu 26.04
guest, where creating a Vulkan instance fails with `ERROR_OUT_OF_HOST_MEMORY` and
`.vm/krunkit.log` shows `Error adding memory map`.

The likely difference is the kernel. Venus maps GPU memory from the Mac into the guest,
and the Hypervisor framework maps memory in 16 KiB pages while the guest kernel uses
4 KiB pages. Fedora 45's kernel, 7.2, offers a virtio-gpu feature for blob alignment
that Ubuntu 26.04's 7.0 lacks. `make gpu` shows it among the features:

```
[drm] features: +context_init +blob_alignment
```

## Things to know

- **`make up` takes longer than a plain boot.** It waits for cloud-init, which installs
  the Vulkan drivers and build tools with `dnf`.
- **The guest user, `fedora`, is in the `render` group.** The GPU's render node,
  `/dev/dri/renderD128`, belongs to that group.
- **The guest user has your Mac's UID.** virtio-fs passes file ownership through, so
  that the guest can write `results/` in your project folder.
- **Port 2222 must be free.** `make up` stops with a message if something else listens
  there; pick another port with `SSH_PORT=...` and pass it to every later command.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.
- **`.vm/` holds the VM's private SSH key.** The project folder, including that key, is
  shared with the guest. The key only opens this VM, and its SSH port listens on
  `127.0.0.1` only.

## Cleaning up

```bash
make destroy
make purge
```
