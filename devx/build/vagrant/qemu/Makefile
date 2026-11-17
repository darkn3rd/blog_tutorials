BOX_NAME ?= local/ubuntu-26.04
BOX_FILE ?= output/ubuntu-26.04-qemu.box

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE := images/$(IMAGE_NAME)

# Vagrant's cloud_init setting is experimental and depends on its disks setting.
BUILD := VAGRANT_EXPERIMENTAL=cloud_init,disks vagrant

TEST := cd test &&

.DELETE_ON_ERROR:
.PHONY: all image build add test verify ssh destroy clean purge

all: build add test

image: $(IMAGE)

build: $(BOX_FILE)

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
	vagrant destroy --force
	$(TEST) vagrant destroy --force

clean: destroy
	rm -rf output

purge: clean
	@if vagrant box list | grep -q '^$(BOX_NAME) *(libvirt'; then \
		vagrant box remove $(BOX_NAME) --provider libvirt --all --force; \
	else \
		echo "No added box to remove."; \
	fi
	rm -f $(IMAGE)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

# Boot the cloud image, let cloud-init and the cleanup script run, then package
# the VM's disk. The build VM is deleted afterwards; only the box file remains.
$(BOX_FILE): $(IMAGE) Vagrantfile cloud-init/user-data scripts/cleanup.sh
	vagrant destroy --force
	$(BUILD) up --provider=qemu
	mkdir -p $(dir $@)
	rm -f $@
	vagrant package --output $@
	vagrant destroy --force
