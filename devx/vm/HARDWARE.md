# Virtual hardware

<!-- Written by hwinfo-all.sh from hardware.tsv. Don't edit by hand. -->

What the guest sees in each tutorial's VM, reported by `hwinfo.sh` from inside the guest right after a fresh `make up`.

## Platform

| Field | `lima/ansible` | `qemu/ansible` | `krunkit/ansible` | `vfkit/ansible` | `virtualbox/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Hypervisor (systemd-detect-virt) | apple | qemu | vm-other | apple | none | none | qemu |
| System vendor | Apple Inc. | QEMU | Libkrun | Apple Inc. | n/a | n/a | QEMU |
| System product | Apple Virtualization Generic Platform | QEMU Virtual Machine | libkrun Virtual Machine | Apple Virtualization Generic Platform | n/a | n/a | QEMU Virtual Machine |
| System version | 1 | virt-11.1 | n/a | 1 | n/a | n/a | virt-11.1 |
| Board | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| Hardware description | ACPI | ACPI | device tree | ACPI | ACPI | ACPI | ACPI |
| ACPI tables | APIC, DSDT, FACP, GTDT, MCFG | APIC, DBG, DSDT, FACP, GTDT, IORT, MCFG, PPTT, SPCR |  | APIC, DSDT, FACP, GTDT, MCFG | APIC, BGRT, DSDT, FACP, GTDT, MCFG | APIC, BGRT, DSDT, FACP, GTDT, MCFG | APIC, DBG, DSDT, FACP, GTDT, IORT, MCFG, PPTT, SPCR |
| Device tree model |  |  | n/a |  |  |  |  |
| Device tree compatible |  |  | linux, dummy-virt |  |  |  |  |

## Firmware and boot

| Field | `lima/ansible` | `qemu/ansible` | `krunkit/ansible` | `vfkit/ansible` | `virtualbox/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Boot mode | UEFI (64-bit) | UEFI (64-bit) | UEFI (64-bit) | UEFI (64-bit) | UEFI (64-bit) | UEFI (64-bit) | UEFI (64-bit) |
| Firmware vendor | Apple Inc. | EDK II | libkrun | Apple Inc. | n/a | n/a | EDK II |
| Firmware version | 2103.160.2.0.0 07/31/2026 | edk2-stable202408-prebuilt.qemu.org 08/13/2024 | 0 01/05/2024 | 2103.160.2.0.0 07/31/2026 | n/a | n/a | edk2-stable202408-prebuilt.qemu.org 08/13/2024 |
| Secure Boot | not offered by firmware | not offered by firmware | not offered by firmware | not offered by firmware | disabled | disabled | not offered by firmware |
| EFI variables | 26 visible | 29 visible | 29 visible | 25 visible | 34 visible | 33 visible | 28 visible |
| EFI boot entry | UEFI Misc Device (Boot0000) | UEFI Misc Device (Boot0001) | UEFI Misc Device (Boot0001) | UEFI Misc Device (Boot0000) | UEFI VBOX HARDDISK VB7b52b557-eb0272ec (Boot0002) | Ubuntu (Boot0002) | UEFI Misc Device (Boot0001) |
| Bootloader | GRUB (BOOT_IMAGE= on the kernel command line) | GRUB (BOOT_IMAGE= on the kernel command line) | GRUB (BOOT_IMAGE= on the kernel command line) | GRUB (BOOT_IMAGE= on the kernel command line) | GRUB (BOOT_IMAGE= on the kernel command line) | GRUB (BOOT_IMAGE= on the kernel command line) | GRUB (BOOT_IMAGE= on the kernel command line) |
| Kernel command line | BOOT_IMAGE=/vmlinuz-7.0.0-34-generic root=LABEL=cloudimg-rootfs ro console=tty1 console=ttyAMA0 | BOOT_IMAGE=/vmlinuz-7.0.0-43-generic root=LABEL=cloudimg-rootfs ro console=tty1 console=ttyAMA0 | BOOT_IMAGE=/vmlinuz-7.0.0-43-generic root=LABEL=cloudimg-rootfs ro console=tty1 console=ttyAMA0 | BOOT_IMAGE=/vmlinuz-7.0.0-43-generic root=LABEL=cloudimg-rootfs ro console=tty1 console=ttyAMA0 | BOOT_IMAGE=/vmlinuz-7.0.0-38-generic root=LABEL=cloudimg-rootfs ro console=tty1 console=ttyAMA0 | BOOT_IMAGE=/vmlinuz-7.0.0-44-generic root=UUID=882916ad-adf1-438e-82ee-bf415e4a3496 ro console=tty1 console=ttyAMA0 | BOOT_IMAGE=/vmlinuz-7.0.0-44-generic root=UUID=882916ad-adf1-438e-82ee-bf415e4a3496 ro console=tty1 console=ttyAMA0 |
| Init (PID 1) | systemd | systemd | systemd | systemd | systemd | systemd | systemd |
| Boot time (systemd-analyze) | 205ms (kernel) + 1.278s (initrd) + 7.998s (userspace) = 9.482s | 255ms (kernel) + 2.150s (initrd) + 6.905s (userspace) = 9.311s | 220ms (kernel) + 2.040s (initrd) + 5.439s (userspace) = 7.700s | 196ms (kernel) + 1.307s (initrd) + 5.154s (userspace) = 6.658s | 268ms (kernel) + 2.736s (initrd) + 6.145s (userspace) = 9.150s | 216ms (kernel) + 1.390s (initrd) + 2.726s (userspace) = 4.333s | 186ms (kernel) + 2.110s (initrd) + 2.884s (userspace) = 5.181s |

## CPU

| Field | `lima/ansible` | `qemu/ansible` | `krunkit/ansible` | `vfkit/ansible` | `virtualbox/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Architecture | aarch64 | aarch64 | aarch64 | aarch64 | aarch64 | aarch64 | aarch64 |
| Vendor | Apple | Apple | Apple | Apple | Apple | Apple | Apple |
| Model | CPU part 0x000 | CPU part 0x000 | CPU part 0x000 | CPU part 0x000 | CPU part 0x000 | CPU part 0x000 | CPU part 0x000 |
| vCPUs | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
| Topology (sockets x cores x threads) | 1 x 2 x 1 | 1 x 2 x 1 | - x 2 x 1 | 1 x 2 x 1 | - x 2 x 1 | - x 2 x 1 | 1 x 2 x 1 |
| Notable flags | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca | aes pmull sha1 sha2 sha3 sha512 crc32 atomics asimd paca |
| Nested virtualization (/dev/kvm) | no | no | no | no | no | no | no |
| Clocksource | arch_sys_counter | arch_sys_counter | arch_sys_counter | arch_sys_counter | arch_sys_counter | arch_sys_counter | arch_sys_counter |
| Memory | 3.8 GiB | 3.8 GiB | 3.8 GiB | 3.8 GiB | 3.7 GiB | 3.7 GiB | 3.8 GiB |

## Video and GPU

| Field | `lima/ansible` | `qemu/ansible` | `krunkit/ansible` | `vfkit/ansible` | `virtualbox/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DRM devices | none | none |  | none |  |  | none |
| PCI display controllers | none | none | none | none | none | none | none |
| Connectors | none | none | none | none | Unknown-1 connected 1280x800 | Unknown-1 connected 1280x800 | none |
| Render nodes | none | none | /dev/dri/renderD128 | none | none | none | none |
| Framebuffer | none | none | none | none | simpledrmdrmfb | simpledrmdrmfb | none |
| virtio-gpu features (kernel log) | none | none | [drm] features: +virgl +edid +resource_blob +host_visible, [drm] features: +context_init | none | none | none | none |
| DRM card0 |  |  | virtio_gpu (virtio-mmio, platform/a007000.virtio_mmio) |  | simple-framebuffer (platform/simple-framebuffer.0) | simple-framebuffer (platform/simple-framebuffer.0) |  |

## OS

| Field | `lima/ansible` | `qemu/ansible` | `krunkit/ansible` | `vfkit/ansible` | `virtualbox/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Distribution | Ubuntu 26.04.1 LTS | Ubuntu 26.04.1 LTS | Ubuntu 26.04.1 LTS | Ubuntu 26.04.1 LTS | Ubuntu 26.04.1 LTS | Ubuntu 26.04.1 LTS | Ubuntu 26.04.1 LTS |
| ID / version / codename | ubuntu 26.04 resolute | ubuntu 26.04 resolute | ubuntu 26.04 resolute | ubuntu 26.04 resolute | ubuntu 26.04 resolute | ubuntu 26.04 resolute | ubuntu 26.04 resolute |
| Kernel | 7.0.0-34-generic | 7.0.0-43-generic | 7.0.0-43-generic | 7.0.0-43-generic | 7.0.0-38-generic | 7.0.0-44-generic | 7.0.0-44-generic |
| Kernel build | #34-Ubuntu SMP PREEMPT_DYNAMIC Wed Sep 2 14:34:54 UTC 2026 | #43-Ubuntu SMP PREEMPT_DYNAMIC Fri Oct 23 13:33:03 UTC 2026 | #43-Ubuntu SMP PREEMPT_DYNAMIC Fri Oct 23 13:33:03 UTC 2026 | #43-Ubuntu SMP PREEMPT_DYNAMIC Fri Oct 23 13:33:03 UTC 2026 | #38-Ubuntu SMP PREEMPT_DYNAMIC Fri Sep 4 09:28:02 UTC 2026 | #44-Ubuntu SMP PREEMPT_DYNAMIC Fri Nov 6 02:50:28 UTC 2026 | #44-Ubuntu SMP PREEMPT_DYNAMIC Fri Nov 6 02:50:28 UTC 2026 |
| Hostname | lima-dev | dev | dev | dev | dev | hako | hako |
| cloud-init datasource | nocloud | nocloud | nocloud | nocloud | nocloud | disabled | disabled |

## Devices

| Field | `lima/ansible` | `qemu/ansible` | `krunkit/ansible` | `vfkit/ansible` | `virtualbox/ansible` | `vagrant/virtualbox/ansible` | `vagrant/qemu/ansible` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| virtio devices | balloon (PCI, virtio_balloon), 2x block (PCI, virtio_blk), console (PCI, virtio_console), fs (PCI, virtiofs), net (PCI, virtio_net), rng (PCI, virtio_rng), vsock (PCI, vmw_vsock_virtio_transport) | 9p (PCI, 9pnet_virtio), 2x block (PCI, virtio_blk), net (PCI, virtio_net) | balloon (MMIO, virtio_balloon), 2x block (MMIO, virtio_blk), console (MMIO, virtio_console), fs (MMIO, virtiofs), gpu (MMIO, virtio_gpu), net (MMIO, virtio_net), rng (MMIO, virtio_rng) | 2x block (PCI, virtio_blk), console (PCI, virtio_console), fs (PCI, virtiofs), net (PCI, virtio_net), rng (PCI, virtio_rng) | net (PCI, virtio_net) | net (PCI, virtio_net), scsi (PCI, virtio_scsi) | block (PCI, virtio_blk), net (other, virtio_net) |
| Network interfaces | eth0: virtio_net | enp0s1: virtio_net | eth0: virtio_net | enp0s1: virtio_net | enp0s8: virtio_net | enp0s8: virtio_net | eth0: virtio_net |
| Disks | vda 20G virtio, vdb 19.1M virtio | vda 20G virtio, vdb 900K virtio | vda 20G virtio, vdb 900K virtio | vda 20G virtio, vdb 42K virtio | sda 20G sata VBOX HARDDISK, sr0 900K sata VBOX CD-ROM | sda 64G HARDDISK | vda 64G virtio |
| Storage controllers | 2x Mass storage controller [0180]: Red Hat, Inc. Virtio 1.0 block device [1af4:1042], Mass storage controller [0180]: Red Hat, Inc. Virtio 1.0 file system [1af4:105a] | 2x SCSI storage controller [0100]: Red Hat, Inc. Virtio block device [1af4:1001] | n/a | 2x Mass storage controller [0180]: Red Hat, Inc. Virtio 1.0 block device [1af4:1042], Mass storage controller [0180]: Red Hat, Inc. Virtio 1.0 file system [1af4:105a] | SATA controller [0106]: Intel Corporation 82801HM/HEM (ICH8M/ICH8M-E) SATA Controller [AHCI mode] [8086:2829] | SCSI storage controller [0100]: Red Hat, Inc. Virtio 1.0 SCSI [1af4:1048] | SCSI storage controller [0100]: Red Hat, Inc. Virtio block device [1af4:1001] |
| File shares | /workspace (virtiofs, lima-b8e612a8b2a76111) | /workspace (9p, workspace) | /workspace (virtiofs, workspace) | /workspace (virtiofs, workspace) | /workspace (vboxsf, workspace) | /workspace (vboxsf, workspace) | n/a |

- **n/a** means the guest didn't expose the value or the tool to read it is missing; **none** means it was checked and nothing was found.
- **Boot time** comes from `systemd-analyze`. Firmware and loader time only show when the firmware reports them to the guest.
- **Measured on** an Apple M1 Max with macOS 26.6.2, 2026-11-26.
- **Not inspected:** `vagrant/avf/ansible`, SSH to the VM fails in testing.
