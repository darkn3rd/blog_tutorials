# A GPU in a QEMU VM on Linux

This project runs an Ubuntu 26.04 virtual machine with QEMU directly, without libvirt,
and gives it a GPU in one of four ways. A Makefile drives every step: downloading the
image, creating the disk, building the cloud-init seed, starting QEMU, and benchmarking
the GPU. QEMU runs as you, with its own user-mode network, so only the VFIO modes need
root.

| `GPU=` | What the guest gets | Guest APIs | The host keeps its GPU |
| --- | --- | --- | --- |
| `virgl` (default) | A virtio-gpu that forwards OpenGL to the host's GPU | OpenGL only | Yes |
| `venus` | A virtio-gpu that forwards Vulkan to the host's GPU | Vulkan, OpenGL | Yes |
| `gvtg` | A slice of an Intel iGPU (GVT-g), with the guest's own Intel driver | Vulkan, OpenGL | Yes, shared |
| `passthrough` | A whole GPU, handed over with VFIO | Whatever its driver offers | No, while the VM runs |

`virgl` is the default here, unlike in [`libvirt`](../libvirt), because it works with
the QEMU in older distributions such as Ubuntu 22.04. `venus` needs QEMU 9.2.

There is no configuration step: cloud-init installs the Vulkan and OpenGL drivers and
the build tools on first boot, and `make bench` builds and runs the benchmark.

## Requirements

- Linux on x86_64, with KVM, and your user able to open `/dev/kvm` (the `kvm` group)
- QEMU and `qemu-img`
- UEFI firmware for VMs (`ovmf`)
- `mtools`, to build the cloud-init seed, and `rsync`

For `virgl` and `venus`:

- A GPU on the host with a working Mesa or vendor OpenGL driver, and its render node,
  usually `/dev/dri/renderD128`, which your desktop session can normally open
- QEMU's OpenGL support. Ubuntu 24.04 and later package it as
  `qemu-system-modules-opengl`; in Ubuntu 22.04 it is built in.
- For `venus`: QEMU 9.2 or later, built with virglrenderer 1.0 or later with Venus
  enabled, and a host Vulkan driver

For `gvtg`:

- An Intel iGPU from Broadwell to Comet Lake (5th to 10th gen Core). Later Intel GPUs
  dropped GVT-g.
- The kernel command line options `i915.enable_gvt=1 intel_iommu=on`, and the `kvmgt`
  module loaded at boot
- sudo, to create the vGPU and to start QEMU

For `passthrough`:

- An IOMMU, turned on in the firmware (VT-d or AMD-Vi). On many Intel machines, also add
  `intel_iommu=on` to the kernel command line.
- A GPU in its own IOMMU group, whose option ROM supports UEFI
- Another way to reach the host while the VM has the GPU: a second GPU, which can be
  integrated, or SSH
- sudo, to move the GPU to `vfio-pci` and to start QEMU

On Debian or Ubuntu:

```bash
sudo apt-get install -y qemu-system-x86 qemu-utils ovmf mtools rsync
sudo apt-get install -y qemu-system-modules-opengl   # Ubuntu 24.04 and later
```

Or, if you use [mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Checks the host, downloads the image, creates the disk and seed, starts and stops QEMU, and runs the benchmark |
| `cloud-init/` | The guest's first-boot settings: user, SSH key, hostname, and the packages to install |
| `gpu-bench.sh` | Builds llama.cpp's `llama-bench` with Vulkan and runs it on the GPU and on the CPU |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM has 2 CPUs, 4 GiB of memory and a 20 GiB disk, and keeps everything in `.vm/`:
the disk, a copy-on-write overlay on the downloaded image; its UEFI variables; the seed;
the SSH key; `console.log`, the serial console; and `qemu.log`. SSH is forwarded from
`127.0.0.1:2222`. The project folder is copied into the VM at `/workspace`.

## Usage

| make | What it does |
| --- | --- |
| `make check` | Check that the host can do what `GPU` asks for |
| `make up` | Check, download the image, create the VM, start QEMU, wait for cloud-init and copy the project in |
| `make gpu` | Show the GPUs and the Vulkan and OpenGL devices the guest sees |
| `make bench` | Build `llama-bench` in the guest and run it, copying the results back to `results/` |
| `make ssh` | SSH in, starting in `/workspace` |
| `make status` | Report running, stopped or not created |
| `make halt` | Shut the guest down, stopping QEMU after 60s |
| `make reload` | `make halt`, then `make up` |
| `make destroy` | Stop QEMU and delete `.vm/`, keeping the downloaded image |
| `make purge` | Delete the downloaded image |
| `make vgpu`, `make vgpu-remove` | Create or delete the GVT-g vGPU (`make up` creates it) |
| `make vfio-bind`, `make vfio-unbind` | Move the `PCI` functions to `vfio-pci`, or back to their host drivers (`make up`, `halt` and `destroy` do this) |

Each target also has a mise task, such as `mise run up`.

A virtual GPU that forwards OpenGL, which gets CPU-only benchmark numbers but shows the
OpenGL renderer:

```bash
make up
make gpu
make bench
```

A virtual GPU that forwards Vulkan, with QEMU 9.2 or later:

```bash
make destroy up GPU=venus
```

A slice of an Intel iGPU. Turn GVT-g on once (on Pop!_OS, use `kernelstub -a` instead
of editing GRUB), reboot, then check which vGPU types the iGPU offers:

```bash
echo kvmgt | sudo tee /etc/modules-load.d/kvmgt.conf
sudo kernelstub -a "i915.enable_gvt=1 intel_iommu=on"
make check GPU=gvtg
make destroy up GPU=gvtg
```

A whole GPU. Find its PCI functions, usually the GPU and its HDMI audio, and check them:

```bash
lspci -nn | grep -iE 'vga|3d|display|audio'
make check GPU=passthrough PCI=01:00.0,01:00.1
make destroy up GPU=passthrough PCI=01:00.0,01:00.1
```

The GPU is recorded when the disk is created, so switching `GPU` needs `make destroy`
first. Pass the same `GPU` to later commands so `LABEL`, the name in the results,
matches.

`CPUS`, `MEMORY` (MiB), `DISK_SIZE`, `SSH_PORT`, `RENDERNODE`, `HOSTMEM`, `GVT_TYPE`,
`IMAGE` and `QEMU` can be overridden, for example `make up CPUS=8 MEMORY=16384`. To
share the image that `libvirt` downloaded:
`make up IMAGE=../libvirt/images/ubuntu-26.04-server-cloudimg-amd64.img`.

## How each GPU mode is set up

- **`virgl`** uses `-device virtio-vga-gl` with `-display egl-headless,rendernode=...`,
  which renders on the host GPU's render node without a window.
- **`venus`** adds `blob=true,venus=true,hostmem=4G` to the virtio-gpu, and backs guest
  memory with a shared memfd (`-object memory-backend-memfd,share=on`), because Venus
  maps GPU buffers into the guest as blobs that virglrenderer has to reach.
- **`gvtg`** creates a mediated device (mdev) on the iGPU, with a fixed UUID, by writing
  to `/sys/bus/pci/devices/0000:00:02.0/mdev_supported_types/<type>/create`, and gives
  it to QEMU as `-device vfio-pci,sysfsdev=/sys/bus/mdev/devices/<uuid>,display=off`. A
  plain virtio-vga stays the guest's display adapter, and the vGPU renders. The type sets
  how much of the iGPU's memory each vGPU gets: `V5_4` allows two at once, `V5_8` one.
- **`passthrough`** moves each PCI function to `vfio-pci` with `driver_override`, gives
  each one to QEMU as `-device vfio-pci,host=...`, and has no virtual display adapter.
  `make halt` and `make destroy` give the functions back to their host drivers.

For `gvtg` and `passthrough`, QEMU starts with sudo and without a memory-lock limit,
because VFIO pins guest memory, then switches to your user with `-runas` once the
devices are open.

Every mode boots with UEFI, without Secure Boot, because most GPUs need UEFI firmware
to start in a VM.

## What the benchmark measures

`gpu-bench.sh` runs `llama-bench` with a small model, TinyLlama 1.1B, twice: with every
layer on the GPU, and on the CPU alone. It reports tokens per second for processing a
512-token prompt (`pp512`), which is mostly compute, and for generating 128 tokens
(`tg128`), which is mostly memory bandwidth. If Vulkan finds no GPU, as with `virgl`,
only the CPU run happens, so there is always a baseline. It also records the OpenGL
renderer.

The results are appended to `results/<label>.csv`, with the full log next to it.

## Things to know

- **`make up` takes longer than a plain boot.** It waits for cloud-init, which installs
  the drivers and build tools, about 300 MB of packages.
- **User-mode networking is slower than a bridge,** but needs no root and no libvirt.
  The guest reaches the internet through QEMU; the host reaches the guest only on the
  forwarded SSH port.
- **The guest user is in the `render` group**, which owns `/dev/dri/renderD*`. Without
  it, Vulkan and OpenGL can't open the GPU.
- **A GVT-g vGPU lasts until reboot** or `make vgpu-remove`, and `make destroy` leaves
  it in place.
- **An NVIDIA GPU needs NVIDIA's driver in the guest.** For `passthrough` with NVIDIA,
  run `sudo ubuntu-drivers install` in the guest (`make ssh`), then `make reload`.
- **Every device in the GPU's IOMMU group has to be passed through.** `make check` lists
  each group.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.

## Cleaning up

```bash
make destroy
make purge
```
