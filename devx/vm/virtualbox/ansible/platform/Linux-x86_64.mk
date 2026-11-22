# Linux on x86_64: an x86_64 VM with BIOS firmware. Untested; see the README.

IMAGE_ARCH := amd64

VM_TYPE := --platform-architecture=x86 --ostype=Ubuntu_64
VM_HARDWARE := --chipset=ich9 --firmware=bios --graphicscontroller=vmsvga

# VirtualBox reads the seed from a virtual DVD, so it has to be an ISO.
define MAKE_SEED
genisoimage -quiet -output $@ -volid cidata -joliet -rock \
	$(VM_DIR)/seed/user-data $(VM_DIR)/seed/meta-data
endef
