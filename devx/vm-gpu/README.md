# GPUs in virtual machines

Each project here creates a Linux virtual machine with a GPU, using one VM tool, and
benchmarks what the guest can do with it. There is no configuration tool: cloud-init
installs the drivers and build tools on first boot, and `make bench` runs the benchmark.
Every project stands on its own, with its own README.

## What counts as a GPU

Almost every VM tool gives the guest a display adapter, but most only draw a screen, and
the guest renders everything on its CPU. A project is here if the VM tool can give the
guest **hardware-accelerated Vulkan or OpenGL**: a virtual GPU that forwards to the host's
GPU, or the host's real GPU passed through. QEMU on macOS is here too, because the same
VM tool behaves so differently on a Mac and on Linux: Homebrew's build has only a 2D GPU,
which is the baseline that the others are measured against.

## Folders

| Folder | Platforms | VM tool | Guest | GPU options | Guest APIs |
| --- | --- | --- | --- | --- | --- |
| [`krunkit`](krunkit) | macOS arm64 | krunkit (libkrun) | Fedora 45 | virtio-gpu with Venus, always on | Vulkan |
| [`qemu/macos`](qemu/macos) | macOS arm64 | QEMU with Apple's Hypervisor framework | Fedora 45 | `GPU=virtio` (2D, Homebrew's QEMU), `virgl` or `venus` (a QEMU built with virglrenderer) | None, OpenGL or Vulkan |
| [`libvirt`](libvirt) | Linux x86_64 | libvirt, with `virsh` | Ubuntu 26.04 | `GPU=venus`, `virgl` or `passthrough` | Vulkan, OpenGL, or the real GPU's |
| [`qemu/linux`](qemu/linux) | Linux x86_64 | QEMU with KVM, run directly from a Makefile | Ubuntu 26.04 | `GPU=virgl`, `venus`, `gvtg` or `passthrough` | OpenGL, Vulkan, Intel's, or the real GPU's |

Left out, and why:

| VM tool | Host | Why not |
| --- | --- | --- |
| vfkit, Lima, Vagrant with AVF | macOS | Apple's Virtualization framework gives Linux guests a 2D virtio-gpu only |
| VirtualBox, Vagrant with VirtualBox | macOS | Not yet tested. VMSVGA with `--accelerate-3d` offers OpenGL only, no Vulkan, and no passthrough since VirtualBox 6.1 |

Planned: Vagrant with vagrant-libvirt on Linux, which offers the same three modes as
libvirt; OpenGL-only tools on Intel Macs, which need an OpenGL benchmark; and WSL2 on
Windows, which forwards Vulkan, OpenGL and CUDA to the host's GPU.

## The benchmark

Each project has `make gpu`, which shows the GPUs, Vulkan devices and OpenGL renderer the
guest sees, and `make bench`, which runs `gpu-bench.sh` in the guest. That script builds
llama.cpp's `llama-bench` and runs a small model, TinyLlama 1.1B, with every layer on the
GPU and then on the CPU alone. It reports tokens per second for a 512-token prompt
(`pp512`), mostly compute, and for generating 128 tokens (`tg128`), mostly memory
bandwidth. Without a Vulkan GPU, only the CPU run happens, so every VM gets a baseline.

[GPU.md](GPU.md) has the results, with one table per machine: the machine itself
without a VM, then each project's VM on it. Numbers from different machines aren't
comparable, so they never share a table.

To measure them yourself, run:

```bash
./gpu-bench-all.sh
```

It names this machine's platform from its OS and CPU architecture, such as
`macos-arm64`, `macos-x86_64`, `ubuntu-x86_64` or `windows-x86_64`, and describes the
machine (model, CPU, GPU, memory, OS) in `results/<platform>/machine.txt`. Then it runs
`gpu-bench.sh` on the machine itself and goes through the projects in `projects.yaml`
whose `platforms` include this one (`linux-x86_64` matches any Linux distribution on
x86_64). For each project it runs `make up`, `make gpu` and `make bench`, then
`make destroy`. Every system builds the same llama.cpp release, the one named by
`llama_ref` in `projects.yaml`, or the newest one if that is empty.

Results go to `results/<platform>/<name>.csv`, and `GPU.md` is rewritten from every
platform folder there. The CSVs and `machine.txt` are kept in git, so results from the
MacBook and the Ubuntu laptop end up side by side after each machine commits its own;
the run logs aren't.

- **Choose projects** by name, with `host` for the machine itself:
  `./gpu-bench-all.sh host krunkit`.
- **Benchmark a real GPU** in libvirt by setting `PCI` in the `libvirt-passthrough` entry
  of `projects.yaml` and removing its `skip`.
- **Rewrite `GPU.md`** without running anything: `./gpu-bench-all.sh --report`.

Each project keeps its own copy of `gpu-bench.sh`, so it stands on its own.
`gpu-bench-all.sh` refuses to run a project whose copy differs from the one here. After
changing `gpu-bench.sh`, copy it into each project:

```bash
for d in krunkit libvirt qemu/linux qemu/macos; do cp gpu-bench.sh "$d/"; done
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
