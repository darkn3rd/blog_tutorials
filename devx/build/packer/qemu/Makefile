BOX_NAME ?= local/ubuntu-26.04
BOX_FILE ?= output/ubuntu-26.04-qemu.box

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE := images/$(IMAGE_NAME)

# Vagrant ships its insecure private key; cloud-init/user-data authorizes the
# matching public key, so Packer can log in with it.
VAGRANT_KEY ?= $(lastword $(sort $(wildcard /opt/vagrant/embedded/gems/gems/vagrant-*/keys/vagrant.key.ed25519)))
# QEMU's UEFI firmware lives in its share directory, next to its bin directory.
QEMU_SHARE ?= $(abspath $(dir $(realpath $(shell command -v qemu-system-aarch64)))../share/qemu)

PACKER_VARS := \
	-var 'image=$(IMAGE)' \
	-var 'image_checksums=$(IMAGE_BASE_URL)/SHA256SUMS' \
	-var 'box_file=$(BOX_FILE)' \
	-var 'ssh_private_key_file=$(VAGRANT_KEY)' \
	-var 'qemu_share=$(QEMU_SHARE)'

TEST := cd test &&

.DELETE_ON_ERROR:
.PHONY: all image init validate box add test verify ssh destroy clean purge

all: box add test

image: $(IMAGE)

init:
	packer init .

validate: init
	packer validate $(PACKER_VARS) .

box: $(BOX_FILE)

add: $(BOX_FILE)
	vagrant box add --force --name $(BOX_NAME) $(BOX_FILE)

test:
	$(TEST) vagrant up --provider=qemu
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
	rm -rf .build output

purge: clean
	@if vagrant box list | grep -q '^$(BOX_NAME) *(libvirt'; then \
		vagrant box remove $(BOX_NAME) --provider libvirt --all --force; \
	else \
		echo "No added box to remove."; \
	fi
	rm -rf $(IMAGE) packer_cache

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

# packer build boots the image, runs the cleanup script and writes the box.
# -force replaces the .build directory an interrupted build leaves behind.
$(BOX_FILE): $(IMAGE) ubuntu.pkr.hcl cloud-init/user-data cloud-init/meta-data scripts/cleanup.sh
	packer init .
	mkdir -p $(dir $@)
	rm -f $@
	packer build -force $(PACKER_VARS) .
