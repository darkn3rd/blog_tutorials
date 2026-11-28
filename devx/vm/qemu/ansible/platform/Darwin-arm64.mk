# Apple Silicon Mac: QEMU with Apple's Hypervisor framework and UEFI firmware.

IMAGE_ARCH := arm64
QEMU := qemu-system-aarch64

FIRMWARE_DIR := $(shell brew --prefix qemu)/share/qemu
VARS := $(VM_DIR)/efi-vars.fd
FIRMWARE := $(VARS)

MACHINE := -machine virt -accel hvf -cpu host \
	-drive if=pflash,format=raw,readonly=on,file=$(FIRMWARE_DIR)/edk2-aarch64-code.fd \
	-drive if=pflash,format=raw,file=$(VARS)

$(VARS):
	mkdir -p $(VM_DIR)
	cp $(FIRMWARE_DIR)/edk2-arm-vars.fd $@

# hdiutil ships with macOS.
SEED := $(VM_DIR)/seed.iso
define MAKE_SEED
hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed
endef
