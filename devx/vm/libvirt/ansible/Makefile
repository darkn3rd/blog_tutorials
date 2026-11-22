NAME ?= dev
PROVISION ?= false
CPUS ?= 2
MEMORY ?= 4096
DISK_SIZE ?= 20G

LIBVIRT_URI ?= qemu:///system
POOL ?= default
NETWORK ?= default

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-amd64.img
IMAGE ?= images/$(IMAGE_NAME)

# Volumes in the storage pool. The base image is shared by every VM made here.
BASE_VOL := $(IMAGE_NAME)
DISK_VOL := $(NAME).qcow2
SEED_VOL := $(NAME)-seed.img

VM_DIR := .vm
KEY := $(VM_DIR)/id_ed25519
SEED := $(VM_DIR)/seed.img
XML := $(VM_DIR)/domain.xml

VIRSH := virsh --connect $(LIBVIRT_URI)
STATE = $$($(VIRSH) domstate $(NAME) 2>/dev/null)
GET_IP = $(VIRSH) domifaddr $(NAME) 2>/dev/null \
	| awk '$$3 == "ipv4" { sub("/.*", "", $$4); print $$4; exit }'
WITH_IP = ip=$$($(GET_IP)); \
	if [ -z "$$ip" ]; then echo "$(NAME) has no address; is it running?" >&2; exit 1; fi;

SSH_OPTS := -i $(KEY) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

.DELETE_ON_ERROR:
.PHONY: up start create base-volume sync provision verify url ssh status \
	halt reload destroy purge

up: start
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

start: create
	@if [ "$(STATE)" = running ]; then \
		echo "VM is already running."; \
	else \
		$(VIRSH) start $(NAME); \
	fi
	@echo "Waiting for an address..."
	@for i in $$(seq 1 60); do \
		ip=$$($(GET_IP)); [ -n "$$ip" ] && break; \
		if [ "$$i" = 60 ]; then echo "No address; try: $(VIRSH) console $(NAME)" >&2; exit 1; fi; \
		sleep 2; \
	done; \
	echo "Waiting for SSH on $$ip..."; \
	for i in $$(seq 1 60); do \
		ssh $(SSH_OPTS) ubuntu@$$ip true 2>/dev/null && break; \
		if [ "$$i" = 60 ]; then echo "SSH did not come up; try: $(VIRSH) console $(NAME)" >&2; exit 1; fi; \
		sleep 2; \
	done; \
	echo "Waiting for cloud-init..."; \
	ssh $(SSH_OPTS) ubuntu@$$ip cloud-init status --wait >/dev/null
	@$(MAKE) --no-print-directory sync

# Creates the VM's disk and seed volumes and defines the domain, once. The
# domain refers to the volumes by file path, which `virsh vol-path` looks up.
create: base-volume $(SEED)
	@if ! $(VIRSH) dominfo $(NAME) >/dev/null 2>&1; then \
		$(VIRSH) vol-create-as $(POOL) $(DISK_VOL) $(DISK_SIZE) --format qcow2 \
			--backing-vol $(BASE_VOL) --backing-vol-format qcow2 && \
		$(VIRSH) vol-create-as $(POOL) $(SEED_VOL) $$(stat -c %s $(SEED)) --format raw && \
		$(VIRSH) vol-upload --pool $(POOL) $(SEED_VOL) $(SEED) && \
		sed -e 's|@NAME@|$(NAME)|' -e 's|@MEMORY@|$(MEMORY)|' -e 's|@CPUS@|$(CPUS)|' \
			-e 's|@NETWORK@|$(NETWORK)|' \
			-e "s|@DISK@|$$($(VIRSH) vol-path --pool $(POOL) $(DISK_VOL))|" \
			-e "s|@SEED@|$$($(VIRSH) vol-path --pool $(POOL) $(SEED_VOL))|" \
			domain.xml > $(XML) && \
		$(VIRSH) define $(XML); \
	fi

# Copies the downloaded cloud image into the storage pool, once.
base-volume: | $(IMAGE)
	@if ! $(VIRSH) vol-info --pool $(POOL) $(BASE_VOL) >/dev/null 2>&1; then \
		echo "Uploading $(IMAGE) to the $(POOL) storage pool..."; \
		$(VIRSH) vol-create-as $(POOL) $(BASE_VOL) $$(stat -c %s $(IMAGE)) --format raw && \
		$(VIRSH) vol-upload --pool $(POOL) $(BASE_VOL) $(IMAGE) && \
		$(VIRSH) pool-refresh $(POOL) >/dev/null; \
	fi

sync:
	@$(WITH_IP) rsync -a --delete --exclude /.vm/ --exclude /images/ \
		-e "ssh $(SSH_OPTS)" ./ ubuntu@$$ip:/workspace/

provision:
	@$(WITH_IP) ansible-playbook -e ansible_host=$$ip playbook.yaml

verify:
	@$(WITH_IP) curl --include --fail http://$$ip/

url:
	@$(WITH_IP) echo "http://$$ip/"

ssh:
	@$(WITH_IP) ssh $(SSH_OPTS) -t ubuntu@$$ip 'cd /workspace && exec bash -l'

status:
	@state=$(STATE); \
	if [ "$$state" = running ]; then \
		echo "running, address $$($(GET_IP))"; \
	else \
		echo "$${state:-not created}"; \
	fi

halt:
	@if [ "$(STATE)" = running ]; then \
		$(VIRSH) shutdown $(NAME) >/dev/null; \
		for i in $$(seq 1 60); do [ "$(STATE)" = "shut off" ] && exit 0; sleep 1; done; \
		echo "Guest did not shut down; forcing it off." >&2; \
		$(VIRSH) destroy $(NAME) >/dev/null; \
	fi

reload:
	@$(MAKE) --no-print-directory halt
	@$(MAKE) --no-print-directory up

# Deletes the domain and its disk and seed volumes; the base volume stays.
destroy:
	@if $(VIRSH) dominfo $(NAME) >/dev/null 2>&1; then \
		if [ "$(STATE)" = running ]; then $(VIRSH) destroy $(NAME) >/dev/null; fi; \
		$(VIRSH) undefine $(NAME) --remove-all-storage; \
	fi
	rm -rf $(VM_DIR)

purge:
	@if $(VIRSH) dominfo $(NAME) >/dev/null 2>&1; then \
		echo "$(NAME) still uses the base image; run make destroy first." >&2; exit 1; \
	fi
	@if $(VIRSH) vol-info --pool $(POOL) $(BASE_VOL) >/dev/null 2>&1; then \
		$(VIRSH) vol-delete --pool $(POOL) $(BASE_VOL); \
	fi
	rm -f $(IMAGE)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' \
		| sed 's| \*.*|  $@|' | sha256sum -c

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C libvirt-example -f $@

# A FAT image labelled CIDATA works as a cloud-init seed, and mtools builds
# one without root.
$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	rm -f $@
	mformat -i $@ -C -f 1440 -v CIDATA ::
	mcopy -i $@ $(VM_DIR)/seed/user-data $(VM_DIR)/seed/meta-data ::
