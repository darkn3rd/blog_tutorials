WORKSPACE := /workspace
PROVISION ?= false

BOX := local/ubuntu-26.04-arm64
BUILD_DIR := build
BOX_FILE := $(BUILD_DIR)/ubuntu-26.04-arm64.box
STAGE := $(BUILD_DIR)/stage

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE ?= images/$(IMAGE_NAME)

# The provider's cloud-init seed authorizes this published key, as its own boxes do.
KEY_URL := https://raw.githubusercontent.com/sodini-io/vagrant-provider-avf/0.1.0/images/ubuntu/files/avf_insecure_key
PLUGIN_KEY := $(firstword $(wildcard $(HOME)/.vagrant.d/gems/*/gems/vagrant-provider-avf-*/lib/vagrant_provider_avf/data/avf_insecure_key.pub))

.DELETE_ON_ERROR:
.PHONY: up start box provision verify ssh url status halt destroy remove-box purge

up: start
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

start: box
	vagrant up --provider=avf
	@echo "Waiting for cloud-init..."
	@vagrant ssh -c 'cloud-init status --wait' >/dev/null

provision:
	vagrant ssh-config > .vagrant/ssh.config
	ansible-playbook playbook.yaml

verify:
	curl --include --fail "http://$$(vagrant ssh -c 'hostname -I' 2>/dev/null | awk '{print $$1}')/"

ssh:
	vagrant ssh -- -t 'cd $(WORKSPACE) && exec bash -l'

url:
	@echo "http://$$(vagrant ssh -c 'hostname -I' 2>/dev/null | awk '{print $$1}')/"

status:
	vagrant status

halt:
	vagrant halt

destroy:
	vagrant destroy --force

box:
	@if ! vagrant box list | grep -q '^$(BOX) '; then \
		$(MAKE) $(BOX_FILE) && \
		vagrant box add --name $(BOX) $(BOX_FILE) && \
		rm -rf $(BUILD_DIR); \
	fi

remove-box:
	vagrant box remove --force $(BOX)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

$(BOX_FILE): | $(IMAGE)
	rm -rf $(STAGE)
	mkdir -p $(STAGE)/box
	qemu-img convert -O raw $(IMAGE) $(STAGE)/box/disk.img
	curl -fsSL -o $(STAGE)/box/insecure_private_key $(KEY_URL)
	chmod 600 $(STAGE)/box/insecure_private_key
	test "$$(ssh-keygen -y -f $(STAGE)/box/insecure_private_key | cut -d' ' -f1-2)" = "$$(cut -d' ' -f1-2 $(PLUGIN_KEY))"
	cp box-template/metadata.json box-template/Vagrantfile $(STAGE)/
	bsdtar -cf $@ -C $(STAGE) .

purge:
	@if vagrant box list | grep -q '^$(BOX) '; then \
		vagrant box remove --force $(BOX); \
	else \
		echo "No cached box to remove."; \
	fi
	rm -f $(IMAGE)
