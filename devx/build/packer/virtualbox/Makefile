BOX_NAME ?= local/ubuntu-26.04
BOX_FILE ?= output/ubuntu-26.04-virtualbox.box
DISK_SIZE_MB ?= 20480

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE := images/$(IMAGE_NAME)

# The OVF that Packer imports: the cloud image's disk in a VirtualBox VM.
OVF_VM := ubuntu-26.04-ovf
OVF_DIR := .build/ovf
OVF := $(OVF_DIR)/ubuntu-26.04.ovf

# Vagrant ships its insecure private key; cloud-init/user-data authorizes the
# matching public key, so Packer can log in with it.
VAGRANT_KEY ?= $(lastword $(sort $(wildcard /opt/vagrant/embedded/gems/gems/vagrant-*/keys/vagrant.key.ed25519)))

PACKER_VARS := \
	-var 'ovf=$(OVF)' \
	-var 'box_file=$(BOX_FILE)' \
	-var 'ssh_private_key_file=$(VAGRANT_KEY)'

VBOX := VBoxManage -q
TEST := cd test &&

.DELETE_ON_ERROR:
.PHONY: all image ovf init validate box add test verify ssh destroy clean purge

all: box add test

image: $(IMAGE)

ovf: $(OVF)

init:
	packer init .

validate: init
	packer validate $(PACKER_VARS) .

box: $(BOX_FILE)

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
	$(TEST) vagrant destroy --force

clean: destroy
	@if $(VBOX) showvminfo $(OVF_VM) >/dev/null 2>&1; then $(VBOX) unregistervm $(OVF_VM) --delete; fi
	rm -rf .build output

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

# Put the cloud image's disk in an Arm VM and export the VM as an OVF. VirtualBox
# reads the image's qcow2 format directly. The VM is only needed for the export.
# Packer attaches its cloud-init seed to the controller named "SATA", so the
# name matters.
$(OVF): $(IMAGE)
	@if $(VBOX) showvminfo $(OVF_VM) >/dev/null 2>&1; then $(VBOX) unregistervm $(OVF_VM) --delete; fi
	rm -rf .build
	mkdir -p $(OVF_DIR)
	$(VBOX) clonemedium disk $(abspath $(IMAGE)) $(abspath .build/disk.vdi) --format VDI
	$(VBOX) closemedium disk $(abspath $(IMAGE))
	$(VBOX) modifymedium disk $(abspath .build/disk.vdi) --resize $(DISK_SIZE_MB)
	$(VBOX) createvm --name=$(OVF_VM) --platform-architecture=arm --ostype=Ubuntu_arm64 \
		--basefolder=$(abspath .build) --register
	$(VBOX) modifyvm $(OVF_VM) --cpus=2 --memory=2048 --chipset=armv8virtual --firmware=efi \
		--graphicscontroller=qemuramfb --audio-enabled=off --usb-xhci=on \
		--nic1=nat --nic-type1=virtio --cable-connected1=on
	$(VBOX) storagectl $(OVF_VM) --name=SATA --add=sata --controller=IntelAhci --portcount=2
	$(VBOX) storageattach $(OVF_VM) --storagectl=SATA --port=0 --type=hdd --medium=$(abspath .build/disk.vdi)
	$(VBOX) export $(OVF_VM) --output=$(abspath $@) --ovf20
	$(VBOX) unregistervm $(OVF_VM) --delete

# packer build imports the OVF, boots it, runs the cleanup script and writes the box.
# -force replaces the build directory an interrupted build leaves behind.
$(BOX_FILE): $(OVF) ubuntu.pkr.hcl cloud-init/user-data cloud-init/meta-data scripts/cleanup.sh
	packer init .
	mkdir -p $(dir $@)
	rm -f $@
	packer build -force $(PACKER_VARS) .
