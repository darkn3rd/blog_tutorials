# GPU benchmark

<!-- Written by gpu-bench-all.sh from results/*.csv. Don't edit by hand. -->

Tokens per second from llama.cpp's `llama-bench`, on the host itself and in each project's VM, measured with `gpu-bench-all.sh`. Higher is better.

| | Mac, no VM | `krunkit` |
| --- | ---: | ---: |
| Backend | Metal | Vulkan |
| GPU used | Apple M1 Max | Virtio-GPU Venus (Apple M1 Max) |
| OpenGL renderer | – | llvmpipe (LLVM 23.1.5, 128 bits) |
| GPU, prompt (pp512) | 3,864 | 2,169 |
| GPU, generation (tg128) | 273 | 91.9 |
| CPU only, prompt (pp512) | 829 | 229 |
| CPU only, generation (tg128) | 151 | 91.1 |
| CPU threads | 8 | 2 |
| GPU speedup, prompt | 4.7x | 9.5x |
| GPU speedup, generation | 1.8x | 1.0x |

- **pp512** processes a 512-token prompt and **tg128** generates 128 tokens. Each value is the mean of 3 repetitions. Prompt processing is mostly compute, so it shows a GPU best; generation is mostly memory bandwidth.
- **Model:** `tinyllama-1.1b-chat-v1.0.Q4_0.gguf`, with every layer on the GPU (`-ngl 99`) for the GPU rows and `-dev none -ngl 0` for the CPU rows.
- **GPU used none** means Vulkan found no GPU in that VM, so only the CPU rows are measured. Mesa's software renderer, llvmpipe, doesn't count as a GPU. An **OpenGL renderer** of llvmpipe means OpenGL runs on the CPU too.
- **CPU threads** follows each VM's vCPUs, so the CPU rows compare the VMs as the projects configure them, not the hypervisors at equal size.
- **llama.cpp:** b12791 (46ba8b7).
- **Measured** 2026-11-26, on Darwin 25.6.0 arm64.
- **Mac:** Apple M1 Max, macOS 26.6.2.
- **No results yet:** `libvirt-venus` (linux), `libvirt-virgl` (linux). Run `gpu-bench-all.sh` on that OS and copy its `results/*.csv` here.
- **Not measured:** `libvirt-passthrough`, set PCI in args to your GPU's PCI functions, then remove skip.
