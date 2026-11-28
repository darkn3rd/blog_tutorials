# Apple Silicon Mac: an arm64 VM with UEFI firmware.

IMAGE_ARCH := arm64

VM_TYPE := --platform-architecture=arm --ostype=Ubuntu_arm64
VM_HARDWARE := --chipset=armv8virtual --firmware=efi --graphicscontroller=qemuramfb

# hdiutil ships with macOS.
define MAKE_SEED
hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed
endef
