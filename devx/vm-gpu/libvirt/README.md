# A GPU in a libvirt VM on Linux

This project runs an Ubuntu 26.04 virtual machine with libvirt and `virsh` and gives it a
GPU, in one of three ways. A Makefile drives every step: downloading the image, copying
it into libvirt's storage pool, building the cloud-init seed, defining the VM from an XML
file, booting it, and benchmarking the GPU.

| `GPU=` | What the guest gets | Guest APIs | The host keeps its GPU |
| --- | --- | --- | --- |
| `venus` (default) | A virtio-gpu that forwards Vulkan to the host's GPU | Vulkan, OpenGL | Yes |
| `virgl` | A virtio-gpu that forwards OpenGL to the host's GPU | OpenGL only | Yes |
| `passthrough` | A real GPU, handed over with VFIO | Whatever its driver offers | No, while the VM runs |

There is no configuration step: cloud-init installs the Vulkan and OpenGL drivers and
the build tools on first boot, and `make bench` builds and runs the benchmark.

## Requirements

- Linux on x86_64, with KVM (`/dev/kvm` exists)
- libvirt and QEMU, with the system libvirt running (`qemu:///system`) and its `default`
  storage pool and network
- UEFI firmware for VMs (`ovmf`)
- `mtools`, to build the cloud-init seed, and `rsync`
- Your user in the `libvirt` group

For `venus` and `virgl`:

- A GPU on the host with a working Mesa or vendor OpenGL driver, and its render node,
  usually `/dev/dri/renderD128`
- QEMU's OpenGL module. Ubuntu packages it separately as `qemu-system-modules-opengl`.
- For `venus`: QEMU 9.2 or later, built with virglrenderer 1.0 or later with Venus
  enabled, and a host Vulkan driver

For `passthrough`:

- An IOMMU, turned on in the firmware (VT-d or AMD-Vi). On many Intel machines, also add
  `intel_iommu=on` to the kernel command line.
- A GPU in its own IOMMU group, whose option ROM supports UEFI
- Another way to reach the host while the VM has the GPU: a second GPU, which can be
  integrated, or SSH

On Debian or Ubuntu:

```bash
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  qemu-system-modules-opengl ovmf mtools rsync

sudo usermod -aG libvirt "$USER"
```

Then log out and back in, so the group takes effect. Or, if you use
[mise](https://mise.jdx.dev/), let it install whichever are missing:

```bash
mise run deps
```

## Files

| File | Purpose |
| --- | --- |
| `Makefile` | Checks the host, downloads the image, creates the volumes and seed, defines, starts and stops the VM, and runs the benchmark |
| `domain-venus.xml` | The VM's libvirt definition for `GPU=venus` |
| `domain-virgl.xml` | The VM's libvirt definition for `GPU=virgl` |
| `domain-passthrough.xml` | The VM's libvirt definition for `GPU=passthrough` |
| `cloud-init/` | The guest's first-boot settings: user, SSH key, hostname, and the packages to install |
| `gpu-bench.sh` | Builds llama.cpp's `llama-bench` with Vulkan and runs it on the GPU and on the CPU |
| `mise.toml` | `deps` and `versions`, plus mise tasks that run the Makefile |

The VM, named `dev` in libvirt, has 2 CPUs, 4 GiB of memory and a 20 GiB disk. The
project folder is copied into the VM at `/workspace`.

## Usage

| make | What it does |
| --- | --- |
| `make check` | Check that the host can do what `GPU` asks for |
| `make up` | Check, download the image, create the VM, boot it, wait for cloud-init and copy the project in |
| `make gpu` | Show the GPUs and the Vulkan and OpenGL devices the guest sees |
| `make bench` | Build `llama-bench` in the guest and run it, copying the results back to `results/` |
| `make ssh` | SSH in, starting in `/workspace` |
| `make status` | Report running, stopped or not created |
| `make halt` | Shut the guest down, forcing it off after 60s |
| `make reload` | `make halt`, then `make up` |
| `make destroy` | Delete the VM, its UEFI variables and its volumes, keeping the base image |
| `make purge` | Delete the base image |

Each target also has a mise task, such as `mise run up`.

A virtual GPU that forwards Vulkan:

```bash
make up
make gpu
make bench
```

OpenGL only, which gets CPU-only benchmark numbers but shows the OpenGL renderer:

```bash
make destroy up GPU=virgl
```

A real GPU. Find its PCI functions, usually the GPU and its HDMI audio, and check them:

```bash
lspci -nn | grep -iE 'vga|3d|display|audio'
make check GPU=passthrough PCI=01:00.0,01:00.1
make destroy up GPU=passthrough PCI=01:00.0,01:00.1
```

The GPU is chosen when the VM is defined, so switching `GPU` needs `make destroy` first.
Pass the same `GPU` to later commands so `LABEL`, the name in the results, matches.

`CPUS`, `MEMORY`, `DISK_SIZE`, `RENDERNODE` (default `/dev/dri/renderD128`), `HOSTMEM`
(default `4G`) and `NAME` can be overridden, for example `make up CPUS=8 MEMORY=16384`.

## How each GPU mode is set up

- **`venus` and `virgl`** use `<graphics type='egl-headless'>`, which renders on the host
  GPU's render node without a window, and a virtio video device with
  `<acceleration accel3d='yes'/>`. To watch the guest's screen, swap in
  `<graphics type='spice'>` with `<listen type='none'/>` and `<gl enable='yes'/>`, then
  connect with `virt-viewer`.
- **`venus`** also needs guest memory that QEMU can share (`<memoryBacking>` with
  `memfd` and `shared`), and three virtio-gpu properties that libvirt has no settings for
  yet: `blob`, `venus` and `hostmem`. `domain-venus.xml` sets them with
  `<qemu:override>`.
- **`passthrough`** adds one `<hostdev managed='yes'>` per PCI function in `PCI`.
  libvirt moves each one to the `vfio-pci` driver when the VM starts and gives it back
  to its host driver when the VM stops. The VM has no virtual display adapter, so the
  passed-through GPU is its only one.

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
- **The guest user is in the `render` group**, which owns `/dev/dri/renderD*`. Without
  it, Vulkan and OpenGL can't open the GPU.
- **An NVIDIA GPU needs NVIDIA's driver in the guest.** Mesa covers virtio-gpu and
  passed-through AMD and Intel GPUs. For NVIDIA, run `sudo ubuntu-drivers install` in
  the guest (`make ssh`), then `make reload`.
- **Every device in the GPU's IOMMU group has to be passed through.** `make check` lists
  each group. If the GPU shares a group with devices the host needs, passthrough isn't
  practical on that machine.
- **The host can't use a passed-through GPU while the VM runs.** If it is the host's
  only GPU, the host's display goes dark until the VM stops.
- **cloud-init runs once per VM.** Changes to `cloud-init/` apply after `make destroy up`.

## Cleaning up

```bash
make destroy
make purge
```
