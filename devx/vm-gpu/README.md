# GPUs in virtual machines

Each project here creates a Linux virtual machine with a GPU, using one VM tool, and
benchmarks what the guest can do with it. There is no configuration tool: cloud-init
installs the drivers and build tools on first boot, and `make bench` runs the benchmark.
Every project stands on its own, with its own README.

## What counts as a GPU

Almost every VM tool gives the guest a display adapter, but most only draw a screen, and
the guest renders everything on its CPU. A project is here only if the VM tool can give
the guest **hardware-accelerated Vulkan or OpenGL**: a virtual GPU that forwards to the
host's GPU, or the host's real GPU passed through.

## Folders

| Folder | Host | VM tool | Guest | GPU options | Guest APIs |
| --- | --- | --- | --- | --- | --- |
| [`krunkit`](krunkit) | macOS | krunkit (libkrun) | Fedora 45 | virtio-gpu with Venus, always on | Vulkan |
| [`libvirt`](libvirt) | Linux | libvirt, with `virsh` | Ubuntu 26.04 | `GPU=venus`, `virgl` or `passthrough` | Vulkan, OpenGL, or the real GPU's |
| [`qemu`](qemu) | Linux | QEMU, run directly from a Makefile | Ubuntu 26.04 | `GPU=virgl`, `venus`, `gvtg` or `passthrough` | OpenGL, Vulkan, Intel's, or the real GPU's |

Left out, and why:

| VM tool | Host | Why not |
| --- | --- | --- |
| QEMU from Homebrew | macOS | Built without OpenGL, so it only has 2D virtio-gpu and VGA devices |
| vfkit, Lima, Vagrant with AVF | macOS | Apple's Virtualization framework gives Linux guests a 2D virtio-gpu only |
| VirtualBox, Vagrant with VirtualBox | macOS | Not yet tested. VMSVGA with `--accelerate-3d` offers OpenGL only, no Vulkan, and no passthrough since VirtualBox 6.1 |

Planned for Linux hosts: Vagrant with vagrant-libvirt, which offers the same three modes
as libvirt.

## The benchmark

Each project has `make gpu`, which shows the GPUs, Vulkan devices and OpenGL renderer the
guest sees, and `make bench`, which runs `gpu-bench.sh` in the guest. That script builds
llama.cpp's `llama-bench` and runs a small model, TinyLlama 1.1B, with every layer on the
GPU and then on the CPU alone. It reports tokens per second for a 512-token prompt
(`pp512`), mostly compute, and for generating 128 tokens (`tg128`), mostly memory
bandwidth. Without a Vulkan GPU, only the CPU run happens, so every VM gets a baseline.

[GPU.md](GPU.md) has the results, next to the host itself without a VM.

To measure them yourself, run:

```bash
./gpu-bench-all.sh
```

It runs `gpu-bench.sh` on the host first, then goes through the projects in
`projects.yaml` that run on this OS. For each one it runs `make up`, `make gpu` and
`make bench`, then `make destroy`. Every system builds the same llama.cpp release, the
one named by `llama_ref` in `projects.yaml`, or the newest one if that is empty. Results go to
`results/<name>.csv`, and `GPU.md` is rewritten from every file there, so results copied
from another machine show up too. The CSVs are kept in git, so each machine's results
stay with the others; the run logs aren't.

- **Choose projects** by name, with `host` for the machine itself:
  `./gpu-bench-all.sh host krunkit`.
- **Benchmark a real GPU** in libvirt by setting `PCI` in the `libvirt-passthrough` entry
  of `projects.yaml` and removing its `skip`.
- **Rewrite `GPU.md`** without running anything: `./gpu-bench-all.sh --report`.

Each project keeps its own copy of `gpu-bench.sh`, so it stands on its own.
`gpu-bench-all.sh` refuses to run a project whose copy differs from the one here. After
changing `gpu-bench.sh`, copy it into each project:

```bash
for d in krunkit libvirt qemu; do cp gpu-bench.sh "$d/"; done
```

`gpu-bench-all.sh` needs `yq` and `python3`, and benchmarking the host needs what
`gpu-bench.sh` lists at its top: a compiler, `cmake`, the Vulkan headers and `glslc`.
With [mise](https://mise.jdx.dev/), `mise install` fetches `yq` without sudo, and
`mise run deps` installs the host's packages with apt, dnf or Homebrew. Each project's
own `mise run deps` installs its VM tool.

```bash
mise install
mise run deps
mise run bench-all     # or bench-host, or report
```

Building llama.cpp with Vulkan takes several minutes in a VM with 2 vCPUs, and each VM
downloads the 640 MB model once.
