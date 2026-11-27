# GPU benchmark

<!-- Written by gpu-bench-all.sh from results/*/. Don't edit by hand. -->

Tokens per second from llama.cpp's `llama-bench`, on each machine itself and in each project's VM on it, measured with `gpu-bench-all.sh`. Higher is better. Each machine has its own table; compare the VMs within a table, not across machines.

## macOS arm64

Machine: MacBookPro18,4, CPU Apple M1 Max, GPU Apple M1 Max, 64 GB, macOS 26.6.2.

| | This machine, no VM | `krunkit` | `qemu-virtio` |
| --- | ---: | ---: | ---: |
| Backend | Metal | Vulkan | Vulkan |
| GPU used | Apple M1 Max | Virtio-GPU Venus (Apple M1 Max) | none |
| OpenGL renderer | – | llvmpipe (LLVM 23.1.5, 128 bits) | llvmpipe (LLVM 23.1.5, 128 bits) |
| GPU, prompt (pp512) | 3,852 | 2,007 | – |
| GPU, generation (tg128) | 270 | 89.4 | – |
| CPU only, prompt (pp512) | 829 | 221 | 228 |
| CPU only, generation (tg128) | 119 | 85.8 | 89.2 |
| CPU | Apple M1 Max | Apple CPU, model hidden from the guest | Apple CPU, model hidden from the guest |
| CPU threads | 8 | 2 | 2 |
| GPU speedup, prompt | 4.6x | 9.1x | – |
| GPU speedup, generation | 2.3x | 1.0x | – |

## Ubuntu x86_64

| | `libvirt-virgl` | `qemu-virgl` |
| --- | ---: | ---: |
| Backend | Vulkan | Vulkan |
| GPU used | none | none |
| OpenGL renderer | virgl | virgl |
| GPU, prompt (pp512) | – | – |
| GPU, generation (tg128) | – | – |
| CPU only, prompt (pp512) | 65.7 | 64.5 |
| CPU only, generation (tg128) | 26.2 | 26.6 |
| CPU | Intel Core i7-8565U CPU @ 1.80GHz | Intel Core i7-8565U CPU @ 1.80GHz |
| CPU threads | 2 | 2 |
| GPU speedup, prompt | – | – |
| GPU speedup, generation | – | – |

No results yet on this machine: `libvirt-venus`, `qemu-venus`.

## Notes

- **pp512** processes a 512-token prompt and **tg128** generates 128 tokens. Each value is the mean of 3 repetitions. Prompt processing is mostly compute, so it shows a GPU best; generation is mostly memory bandwidth.
- **Model:** TinyLlama 1.1B, Q4_0, with every layer on the GPU (`-ngl 99`) for the GPU rows and `-dev none -ngl 0` for the CPU rows.
- **GPU used none** means Vulkan found no GPU in that VM, so only the CPU rows are measured. Mesa's software renderer, llvmpipe, doesn't count as a GPU. An **OpenGL renderer** of llvmpipe means OpenGL runs on the CPU too.
- **CPU threads** follows each VM's vCPUs, so the CPU rows compare the VMs as the projects configure them, not the hypervisors at equal size.
- **llama.cpp:** b12791 (46ba8b7).
- **Measured** 2026-11-26 to 2026-11-27.
- **Not measured:** `libvirt-passthrough`, set PCI in args to your GPU's PCI functions, then remove skip.
- **Not measured:** `qemu-gvtg`, needs an Intel iGPU with GVT-g turned on (see qemu/linux/README.md), then remove skip.
- **Not measured:** `qemu-passthrough`, set PCI in args to your GPU's PCI functions, then remove skip.
- **Not measured:** `qemu-venus-macos`, needs a QEMU built with OpenGL and virglrenderer with Venus (see qemu/macos/README.md); set QEMU in args, then remove skip.
