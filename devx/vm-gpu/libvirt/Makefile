NAME ?= dev
CPUS ?= 2
MEMORY ?= 4096
DISK_SIZE ?= 20G

# How the guest gets a GPU:
#   venus        virtio-gpu with Vulkan forwarded to the host's GPU
#   virgl        virtio-gpu with OpenGL forwarded to the host's GPU, no Vulkan
#   passthrough  a real GPU, given to the guest with VFIO; set PCI too
GPU ?= venus
# The host GPU that venus and virgl render on.
RENDERNODE ?= /dev/dri/renderD128
# The window of host memory that Venus maps GPU buffers through.
HOSTMEM ?= 4G
# For passthrough: every PCI function of the GPU, comma-separated, as lspci shows them,
# such as 01:00.0,01:00.1 for a card and its HDMI audio.
PCI ?=

# Name for this VM in the benchmark results, and the llama.cpp release to build.
LABEL ?= libvirt-$(GPU)
LLAMA_REF ?= master

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
TEMPLATE := domain-$(GPU).xml

VIRSH := virsh --connect $(LIBVIRT_URI)
STATE = $$($(VIRSH) domstate $(NAME) 2>/dev/null)
GET_IP = $(VIRSH) domifaddr $(NAME) 2>/dev/null \
	| awk '$$3 == "ipv4" { sub("/.*", "", $$4); print $$4; exit }'
WITH_IP = ip=$$($(GET_IP)); \
	if [ -z "$$ip" ]; then echo "$(NAME) has no address; is it running?" >&2; exit 1; fi;

SSH_OPTS := -i $(KEY) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

.DELETE_ON_ERROR:
.PHONY: up check create base-volume sync gpu bench ssh status halt reload destroy purge access

# The checks below hide virsh's errors, so without access to libvirt they would
# report "not created" instead of failing. Every target that runs virsh checks
# access first.
up create base-volume sync gpu bench ssh status halt destroy purge: access

access:
	@$(VIRSH) uri >/dev/null 2>&1 || { \
		echo "Can't connect to libvirt at $(LIBVIRT_URI)." >&2; \
		echo "Is your login session in the libvirt group? Check with: id -nG" >&2; \
		echo "If not, log out and back in, or run: newgrp libvirt" >&2; \
		exit 1; }

# Checks that the host can do what GPU asks for, before anything is created.
check:
	@case "$(GPU)" in \
	venus|virgl) \
		test -e $(RENDERNODE) || { echo "$(RENDERNODE) doesn't exist; set RENDERNODE to a host GPU (ls /dev/dri)." >&2; exit 1; }; \
		echo "Host GPU: $(RENDERNODE) ($$(basename $$(readlink -f /sys/class/drm/$$(basename $(RENDERNODE))/device/driver)))"; \
		if [ "$(GPU)" = venus ] && ! qemu-system-x86_64 -device virtio-vga-gl,help 2>/dev/null | grep -q venus; then \
			echo "This QEMU has no Venus support (needs QEMU 9.2 or later, built with virglrenderer 1.0 or later)." >&2; exit 1; \
		fi ;; \
	passthrough) \
		test -n "$(PCI)" || { echo "Set PCI to the GPU's PCI functions, such as PCI=01:00.0,01:00.1 (see: lspci -nn | grep -iE 'vga|3d|display|audio')." >&2; exit 1; }; \
		test -d /sys/kernel/iommu_groups/0 || { echo "The IOMMU is off. Turn on VT-d or AMD-Vi in the firmware, and add intel_iommu=on to the kernel command line on Intel." >&2; exit 1; }; \
		for a in $$(echo "$(PCI)" | tr ',' ' '); do \
			case $$a in ????:*) ;; *) a=0000:$$a ;; esac; \
			test -e /sys/bus/pci/devices/$$a || { echo "No PCI device $$a." >&2; exit 1; }; \
			lspci -nnk -s $$a | head -3; \
			echo "  IOMMU group $$(basename $$(readlink /sys/bus/pci/devices/$$a/iommu_group)):" \
				$$(ls /sys/bus/pci/devices/$$a/iommu_group/devices); \
		done; \
		echo "Every device in those IOMMU groups has to go to the guest, or the VM won't start." ;; \
	*) echo "Unknown GPU=$(GPU); use venus, virgl or passthrough." >&2; exit 1 ;; \
	esac

up: create
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
	echo "Waiting for cloud-init to install the packages..."; \
	ssh $(SSH_OPTS) ubuntu@$$ip cloud-init status --wait >/dev/null
	@$(MAKE) --no-print-directory sync

# Creates the VM's disk and seed volumes and defines the domain from the template for
# GPU, once. The domain refers to the volumes by file path, which `virsh vol-path`
# looks up. To switch GPU, run `make destroy` first.
create: base-volume $(SEED)
	@if ! $(VIRSH) dominfo $(NAME) >/dev/null 2>&1; then \
		$(MAKE) --no-print-directory check && \
		hostdevs=$$(echo "$(PCI)" | tr ',' '\n' | awk 'NF { \
			a = ($$1 ~ /^[0-9a-fA-F]+:[0-9a-fA-F]+:/) ? $$1 : "0000:" $$1; \
			split(a, p, /[:.]/); \
			printf "<hostdev mode=\"subsystem\" type=\"pci\" managed=\"yes\"><source>" \
				"<address domain=\"0x%s\" bus=\"0x%s\" slot=\"0x%s\" function=\"0x%s\"/>" \
				"</source></hostdev>", p[1], p[2], p[3], p[4] }') && \
		$(VIRSH) vol-create-as $(POOL) $(DISK_VOL) $(DISK_SIZE) --format qcow2 \
			--backing-vol $(BASE_VOL) --backing-vol-format qcow2 && \
		$(VIRSH) vol-create-as $(POOL) $(SEED_VOL) $$(stat -c %s $(SEED)) --format raw && \
		$(VIRSH) vol-upload --pool $(POOL) $(SEED_VOL) $(SEED) && \
		sed -e 's|@NAME@|$(NAME)|' -e 's|@MEMORY@|$(MEMORY)|' -e 's|@CPUS@|$(CPUS)|' \
			-e 's|@NETWORK@|$(NETWORK)|' -e 's|@RENDERNODE@|$(RENDERNODE)|' \
			-e "s|@HOSTMEM@|$$(numfmt --from=iec $(HOSTMEM))|" \
			-e "s|@HOSTDEVS@|$$hostdevs|" \
			-e "s|@DISK@|$$($(VIRSH) vol-path --pool $(POOL) $(DISK_VOL))|" \
			-e "s|@SEED@|$$($(VIRSH) vol-path --pool $(POOL) $(SEED_VOL))|" \
			$(TEMPLATE) > $(XML) && \
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
	@$(WITH_IP) rsync -a --delete --exclude /.vm/ --exclude /images/ --exclude /results/ \
		-e "ssh $(SSH_OPTS)" ./ ubuntu@$$ip:/workspace/

# What the guest sees: its GPUs, and the Vulkan and OpenGL devices.
gpu:
	@$(WITH_IP) ssh $(SSH_OPTS) ubuntu@$$ip 'lspci -nnk | grep -A2 -iE "vga|3d|display"; \
		echo; ls -l /dev/dri; \
		echo; vulkaninfo --summary 2>&1 | grep -E "deviceName|driverName|ERROR" || true; \
		echo; eglinfo -B -p surfaceless 2>/dev/null | grep -E "renderer" || true'

# Builds llama-bench in the guest, runs it, and copies the results back to results/.
bench: sync
	@$(WITH_IP) ssh $(SSH_OPTS) ubuntu@$$ip \
		'LABEL=$(LABEL) LLAMA_REF=$(LLAMA_REF) RESULTS=/workspace/results /workspace/gpu-bench.sh'; \
	rc=$$?; mkdir -p results; \
	rsync -a -e "ssh $(SSH_OPTS)" ubuntu@$$ip:/workspace/results/ results/; \
	exit $$rc

ssh:
	@$(WITH_IP) ssh $(SSH_OPTS) -t ubuntu@$$ip 'cd /workspace && exec bash -l'

status:
	@state=$(STATE); \
	if [ "$$state" = running ]; then \
		echo "running, address $$($(GET_IP)), GPU $$(sed -n 's/.*GPU=\([a-z]*\).*/\1/p' $(XML) 2>/dev/null)"; \
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

# Deletes the domain, its UEFI variables and its disk and seed volumes; the base
# volume stays.
destroy:
	@if $(VIRSH) dominfo $(NAME) >/dev/null 2>&1; then \
		if [ "$(STATE)" = running ]; then $(VIRSH) destroy $(NAME) >/dev/null; fi; \
		$(VIRSH) undefine $(NAME) --nvram --remove-all-storage; \
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
	ssh-keygen -q -t ed25519 -N '' -C libvirt-gpu -f $@

# A FAT image labelled CIDATA works as a cloud-init seed, and mtools builds
# one without root.
$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	rm -f $@
	mformat -i $@ -C -f 1440 -v CIDATA ::
	mcopy -i $@ $(VM_DIR)/seed/user-data $(VM_DIR)/seed/meta-data ::
