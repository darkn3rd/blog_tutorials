# Virtual hardware

<!-- Written by hwinfo-all.sh from results/*/hardware.tsv. Don't edit by hand. -->

What the guest sees in each project's VM, reported by `hwinfo.sh` from inside the guest right after a fresh `make up`: the platform and firmware, the CPU, the video and GPU devices with their Vulkan and OpenGL drivers, the OS and the other devices. Each machine running the VMs has its own part.

## macOS arm64

Machine: MacBookPro18,4, CPU Apple M1 Max, GPU Apple M1 Max, 64 GB, macOS 26.6.2.

### Platform

| Field | `krunkit` | `qemu-virtio` |
| --- | --- | --- |
| Hypervisor (systemd-detect-virt) | vm-other | qemu |
| System vendor | Libkrun | QEMU |
| System product | libkrun Virtual Machine | QEMU Virtual Machine |
| System version | n/a | virt-11.1 |
| Board | n/a | n/a |
| Device tree model | n/a |  |
| Device tree compatible | linux, dummy-virt |  |
| Hardware description | device tree | ACPI |
| ACPI tables |  | APIC, BGRT, DBG, DSDT, FACP, GTDT, IORT, MCFG, PPTT, SPCR |

### Firmware and boot

| Field | `krunkit` | `qemu-virtio` |
| --- | --- | --- |
| Boot mode | UEFI (64-bit) | UEFI (64-bit) |
| Firmware vendor | libkrun | EDK II |
| Firmware version | 0 01/05/2024 | edk2-stable202408-prebuilt.qemu.org 08/13/2024 |
| Secure Boot | not offered by firmware | not offered by firmware |
| EFI variables | 31 visible | 35 visible |
| EFI boot entry | UEFI Misc Device (Boot0001) | UEFI Misc Device (Boot0001) |
| Bootloader | GRUB 2.12 | GRUB 2.12 |
| Kernel command line | BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-7.2.11-300.fc45.aarch64 no_timer_check console=tty1 console=ttyAMA0,115200n8 systemd.firstboot=off root=UUID=d751d330-1a8f-4e36-a511-d727edf3dbca rootflags=subvol=root | BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-7.2.11-300.fc45.aarch64 no_timer_check console=tty1 console=ttyAMA0,115200n8 systemd.firstboot=off root=UUID=d751d330-1a8f-4e36-a511-d727edf3dbca rootflags=subvol=root |
| Init (PID 1) | systemd | systemd |
| Boot time (systemd-analyze) | 220ms (kernel) + 2.365s (initrd) + 2min 21.604s (userspace) = 2min 24.191s | 238ms (kernel) + 2.391s (initrd) + 1min 7.726s (userspace) = 1min 10.356s |

### CPU

| Field | `krunkit` | `qemu-virtio` |
| --- | --- | --- |
| Architecture | aarch64 | aarch64 |
| Vendor | Apple | Apple |
| Model | CPU part 0x000 | CPU part 0x000 |
| vCPUs | 2 | 2 |
| Topology (sockets x cores x threads) | - x 2 x 1 | 1 x 2 x 1 |
| Notable flags | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca |
| Nested virtualization (/dev/kvm) | no | no |
| Clocksource | arch_sys_counter | arch_sys_counter |
| Memory | 3.8 GiB | 3.8 GiB |

### Video and GPU

| Field | `krunkit` | `qemu-virtio` |
| --- | --- | --- |
| DRM card0 | virtio_gpu (virtio-mmio, platform/a007000.virtio_mmio) | virtio_gpu (virtio-pci, PCI 0000:00:03.0: Display controller [0380]: Red Hat, Inc. Virtio 1.0 GPU [1af4:1050] (rev 01)) |
| PCI display controllers | none | Display controller [0380]: Red Hat, Inc. Virtio 1.0 GPU [1af4:1050] |
| Connectors | none | Virtual-1 connected 1280x800 |
| Render nodes | /dev/dri/renderD128 | /dev/dri/renderD128 |
| Framebuffer | none | none |
| virtio-gpu features (kernel log) | [drm] features: +virgl +edid +resource_blob +host_visible, [drm] features: +context_init +blob_alignment | [drm] features: -virgl +edid -resource_blob -host_visible, [drm] features: -context_init -blob_alignment |
| Vulkan devices | Virtio-GPU Venus (Apple M1 Max) (venus), llvmpipe (LLVM 23.1.5, 128 bits) (llvmpipe) | llvmpipe (LLVM 23.1.5, 128 bits) (llvmpipe) |
| OpenGL renderer | llvmpipe (LLVM 23.1.5, 128 bits) | llvmpipe (LLVM 23.1.5, 128 bits) |

### OS

| Field | `krunkit` | `qemu-virtio` |
| --- | --- | --- |
| Distribution | Fedora Linux 45 (Cloud Edition) | Fedora Linux 45 (Cloud Edition) |
| ID / version / codename | fedora 45 - | fedora 45 - |
| Kernel | 7.2.11-300.fc45.aarch64 | 7.2.11-300.fc45.aarch64 |
| Kernel build | #1 SMP PREEMPT_DYNAMIC Thu Oct 15 16:01:14 UTC 2026 | #1 SMP PREEMPT_DYNAMIC Thu Oct 15 16:01:14 UTC 2026 |
| Hostname | dev | dev |
| cloud-init datasource | nocloud | nocloud |

### Devices

| Field | `krunkit` | `qemu-virtio` |
| --- | --- | --- |
| virtio devices | balloon (MMIO, virtio_balloon), 2x block (MMIO, virtio_blk), console (MMIO, virtio_console), fs (MMIO, virtiofs), gpu (MMIO, virtio_gpu), net (MMIO, virtio_net), rng (MMIO, virtio_rng) | 2x block (PCI, virtio_blk), gpu (PCI, virtio_gpu), net (PCI, virtio_net), rng (PCI, virtio_rng) |
| Network interfaces | eth0: virtio_net | enp0s1: virtio_net |
| Disks | vda 20G virtio, vdb 900K virtio | vda 20G virtio, vdb 900K virtio |
| File shares | /workspace (virtiofs, workspace) | n/a |
| Storage controllers |  | 2x SCSI storage controller [0100]: Red Hat, Inc. Virtio block device [1af4:1001] |

## Notes

- **n/a** means the guest didn't expose the value or the tool to read it is missing; **none** means it was checked and nothing was found.
- **Vulkan devices** lists each device with its driver: `venus` forwards to the host's GPU, `llvmpipe` runs on the CPU. **OpenGL renderer** comes from `eglinfo` without a display.
- **Boot time** comes from `systemd-analyze`, and includes cloud-init installing the packages. Firmware and loader time only show when the firmware reports them.
- **Inspected** 2026-11-26.
