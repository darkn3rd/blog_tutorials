# Linux on x86_64: QEMU with KVM and its default BIOS firmware.

IMAGE_ARCH := amd64
QEMU := qemu-system-x86_64

FIRMWARE :=

MACHINE := -machine q35 -accel kvm -cpu host

# A FAT image labelled CIDATA works as a cloud-init seed, and mtools builds
# one without root.
SEED := $(VM_DIR)/seed.img
define MAKE_SEED
rm -f $@
mformat -i $@ -C -f 1440 -v CIDATA ::
mcopy -i $@ $(VM_DIR)/seed/user-data $(VM_DIR)/seed/meta-data ::
endef
