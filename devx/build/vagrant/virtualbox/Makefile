BOX_NAME ?= local/ubuntu-26.04
BOX_FILE ?= output/ubuntu-26.04-virtualbox.box
DISK_SIZE_MB ?= 20480

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE := images/$(IMAGE_NAME)

# The base box: the cloud image in a VirtualBox VM, with no vagrant user yet.
BUILD_DIR := .build
BASE_VM := ubuntu-26.04-base
BASE_DISK := $(BUILD_DIR)/disk.vdi
BASE_BOX_NAME := local/ubuntu-26.04-base
BASE_BOX := $(BUILD_DIR)/ubuntu-26.04-base.box

VBOX := VBoxManage -q
# Vagrant's cloud_init setting is experimental and depends on its disks setting.
BUILD := VAGRANT_EXPERIMENTAL=cloud_init,disks vagrant
TEST := cd test &&

.DELETE_ON_ERROR:
.PHONY: all image base build add test verify ssh destroy clean purge

all: build add test

image: $(IMAGE)

base: $(BASE_BOX)

build: $(BOX_FILE)

add: $(BOX_FILE)
	vagrant box add --force --name $(BOX_NAME) $(BOX_FILE)

test:
	$(TEST) vagrant up --provider=virtualbox
	@$(MAKE) --no-print-directory verify

verify:
	$(TEST) vagrant ssh -c 'echo "user: $$(whoami)"; \
		sudo -n true && echo "sudo: passwordless"; \
		. /etc/os-release && echo "os: $$PRETTY_NAME"; \
		df -h / | tail -1 | awk "{print \"disk: \" \$$2 \" root filesystem\"}"'

ssh:
	$(TEST) vagrant ssh

destroy:
	vagrant destroy --force
	$(TEST) vagrant destroy --force

clean: destroy
	@if $(VBOX) showvminfo $(BASE_VM) >/dev/null 2>&1; then $(VBOX) unregistervm $(BASE_VM) --delete; fi
	@if vagrant box list | grep -q '^$(BASE_BOX_NAME) '; then \
		vagrant box remove $(BASE_BOX_NAME) --provider virtualbox --all --force; \
	fi
	rm -rf $(BUILD_DIR) output

purge: clean
	@if vagrant box list | grep -q '^$(BOX_NAME) *(virtualbox'; then \
		vagrant box remove $(BOX_NAME) --provider virtualbox --all --force; \
	else \
		echo "No added box to remove."; \
	fi
	rm -f $(IMAGE)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

# Step 1: put the cloud image's disk in a VirtualBox VM and let
# `vagrant package --base` export that VM as a box. VirtualBox reads the image's
# qcow2 format directly. The VM is only needed for the export, so it is deleted.
$(BASE_BOX): $(IMAGE)
	@if $(VBOX) showvminfo $(BASE_VM) >/dev/null 2>&1; then $(VBOX) unregistervm $(BASE_VM) --delete; fi
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	$(VBOX) clonemedium disk $(abspath $(IMAGE)) $(abspath $(BASE_DISK)) --format VDI
	$(VBOX) closemedium disk $(abspath $(IMAGE))
	$(VBOX) modifymedium disk $(abspath $(BASE_DISK)) --resize $(DISK_SIZE_MB)
	$(VBOX) createvm --name=$(BASE_VM) --platform-architecture=arm --ostype=Ubuntu_arm64 \
		--basefolder=$(abspath $(BUILD_DIR)) --register
	$(VBOX) modifyvm $(BASE_VM) --cpus=2 --memory=2048 --chipset=armv8virtual --firmware=efi \
		--graphicscontroller=qemuramfb --audio-enabled=off --usb-xhci=on \
		--nic1=nat --nic-type1=virtio --cable-connected1=on
	$(VBOX) storagectl $(BASE_VM) --name=SATA --add=sata --controller=IntelAhci --portcount=2
	$(VBOX) storageattach $(BASE_VM) --storagectl=SATA --port=0 --type=hdd --medium=$(abspath $(BASE_DISK))
	vagrant package --base $(BASE_VM) --output $@
	$(VBOX) unregistervm $(BASE_VM) --delete

# Step 2: start a VM from the base box, let cloud-init and the cleanup script
# run, then package it. The build VM and the base box are deleted afterwards;
# only the box file remains.
$(BOX_FILE): $(BASE_BOX) Vagrantfile cloud-init/user-data scripts/cleanup.sh
	vagrant box add --force --name $(BASE_BOX_NAME) $(BASE_BOX)
	vagrant destroy --force
	$(BUILD) up --provider=virtualbox
	mkdir -p $(dir $@)
	rm -f $@
	vagrant package --output $@
	vagrant destroy --force
	vagrant box remove $(BASE_BOX_NAME) --provider virtualbox --all --force
