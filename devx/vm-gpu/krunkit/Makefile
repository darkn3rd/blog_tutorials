SSH_PORT ?= 2222
CPUS ?= 2
MEMORY ?= 4G
DISK_SIZE ?= 20G
# Name for this VM in the benchmark results, and the llama.cpp release to build.
LABEL ?= krunkit
LLAMA_REF ?= master

# Fedora, because its kernel and Mesa are new enough for Venus under krunkit.
FEDORA_RELEASE ?= 45
FEDORA_BUILD ?= 1.4
IMAGE_BASE_URL ?= https://download.fedoraproject.org/pub/fedora/linux/releases/$(FEDORA_RELEASE)/Cloud/aarch64/images
IMAGE_NAME := Fedora-Cloud-Base-Generic-$(FEDORA_RELEASE)-$(FEDORA_BUILD).aarch64.qcow2
CHECKSUM_NAME := Fedora-Cloud-$(FEDORA_RELEASE)-$(FEDORA_BUILD)-aarch64-CHECKSUM
IMAGE ?= images/$(IMAGE_NAME)
RAW_IMAGE := $(basename $(IMAGE)).raw

VM_DIR := $(CURDIR)/.vm
DISK := $(VM_DIR)/disk.raw
SEED := $(VM_DIR)/seed.iso
KEY := $(VM_DIR)/id_ed25519
PID := $(VM_DIR)/krunkit.pid
API := $(VM_DIR)/krunkit.sock
NET_PID := $(VM_DIR)/gvproxy.pid
NET_SOCK := $(VM_DIR)/net.sock
NET_API := $(VM_DIR)/gvproxy.sock

# gvproxy gives the guest 192.168.127.2 for this MAC address.
GUEST_MAC := 5a:94:ef:e4:0c:ee

# gvproxy isn't packaged on its own in Homebrew; Podman ships a copy.
GVPROXY ?= $(shell command -v gvproxy || echo $$(brew --prefix)/opt/podman/libexec/podman/gvproxy)

SSH := ssh -i $(KEY) -p $(SSH_PORT) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	fedora@127.0.0.1
RUNNING := { test -f $(PID) && kill -0 "$$(cat $(PID))"; } 2>/dev/null
NET_RUNNING := { test -f $(NET_PID) && kill -0 "$$(cat $(NET_PID))"; } 2>/dev/null

.DELETE_ON_ERROR:
.PHONY: up network gpu hwinfo bench ssh status halt reload destroy purge

# gvproxy is the VM's network: DHCP, DNS, NAT and SSH on 127.0.0.1.
network:
	@if ! $(NET_RUNNING); then \
		if lsof -nP -iTCP:$(SSH_PORT) -sTCP:LISTEN >/dev/null; then \
			echo "Port $(SSH_PORT) is in use; pick another with SSH_PORT=...:" >&2; \
			lsof -nP -iTCP:$(SSH_PORT) -sTCP:LISTEN >&2; exit 1; \
		fi; \
		mkdir -p $(VM_DIR); \
		rm -f $(NET_SOCK) $(NET_API); \
		$(GVPROXY) -listen-vfkit unixgram://$(NET_SOCK) -listen unix://$(NET_API) \
			-ssh-port $(SSH_PORT) -pid-file $(NET_PID) -log-file $(VM_DIR)/gvproxy.log \
			</dev/null >/dev/null 2>&1 & \
		for i in $$(seq 1 50); do test -S $(NET_API) && break; sleep 0.1; done; \
		test -S $(NET_API) || { echo "gvproxy did not start:" >&2; cat $(VM_DIR)/gvproxy.log >&2; exit 1; }; \
	fi

# krunkit always gives the guest a virtio-gpu that forwards Vulkan to the Mac's GPU
# (Venus, through MoltenVK), so there is no GPU option to add here.
up: $(DISK) $(SEED) network
	@if $(RUNNING); then \
		echo "VM is already running."; \
	else \
		rm -f $(API); \
		krunkit --cpus $(CPUS) --memory $(MEMORY) \
			--device virtio-blk,path=$(DISK),format=raw \
			--device virtio-blk,path=$(SEED),format=raw \
			--device virtio-net,unixSocketPath=$(NET_SOCK),mac=$(GUEST_MAC) \
			--device virtio-fs,sharedDir=$(CURDIR),mountTag=workspace \
			--device virtio-serial,logFilePath=$(VM_DIR)/console.log \
			--restful-uri unix://$(API) \
			--pidfile $(PID) --log-file $(VM_DIR)/krunkit.log \
			</dev/null >/dev/null 2>&1 & \
		for i in $$(seq 1 50); do $(RUNNING) && break; sleep 0.1; done; \
	fi
	@echo "Waiting for SSH..."
	@for i in $$(seq 1 60); do \
		$(SSH) true 2>/dev/null && break; \
		if [ "$$i" = 60 ]; then echo "SSH did not come up; see $(VM_DIR)/console.log and krunkit.log" >&2; exit 1; fi; \
		sleep 2; \
	done
	@echo "Waiting for cloud-init to install the packages..."
	@# Fedora lets only root read cloud-init's state; as another user, --wait never ends.
	@$(SSH) sudo cloud-init status --wait >/dev/null

# The full report of the virtual hardware the guest sees, GPU included, from hwinfo.sh.
# HWINFO_ARGS=--tsv prints raw section/field/value rows instead of Markdown.
hwinfo:
	@$(SSH) 'sudo /workspace/hwinfo.sh $(HWINFO_ARGS)'

# What the guest sees: the virtio-gpu, its features, and the Vulkan and OpenGL devices.
gpu:
	@$(SSH) 'ls -l /dev/dri; \
		echo; sudo dmesg | grep -E "\[drm\] (features|cap set)"; \
		echo; vulkaninfo --summary 2>&1 | grep -E "deviceName|driverName|ERROR" || true; \
		echo; eglinfo -B -p surfaceless 2>/dev/null | grep -E "renderer" || true'

# Builds llama-bench in the guest and runs it. The results land in results/ through
# the virtio-fs share; the build stays in the guest's home folder, which is faster.
bench:
	$(SSH) 'LABEL=$(LABEL) LLAMA_REF=$(LLAMA_REF) RESULTS=/workspace/results /workspace/gpu-bench.sh'

ssh:
	$(SSH) -t 'cd /workspace && exec bash -l'

status:
	@if $(RUNNING); then \
		echo "running (pid $$(cat $(PID))), ssh 127.0.0.1:$(SSH_PORT)"; \
	elif [ -f $(DISK) ]; then \
		echo "stopped"; \
	else \
		echo "not created"; \
	fi

# "Stop" asks the guest to shut down; "HardStop" stops the VM without asking.
halt:
	@if $(RUNNING); then \
		curl -fsS --unix-socket $(API) http://krunkit/vm/state -X POST -d '{"state":"Stop"}' >/dev/null; \
		for i in $$(seq 1 60); do $(RUNNING) || break; sleep 1; done; \
		if $(RUNNING); then \
			echo "Guest did not shut down; stopping krunkit." >&2; \
			curl -fsS --unix-socket $(API) http://krunkit/vm/state -X POST -d '{"state":"HardStop"}' >/dev/null; \
			for i in $$(seq 1 10); do $(RUNNING) || break; sleep 1; done; \
			if $(RUNNING); then kill "$$(cat $(PID))"; fi; \
		fi; \
	fi
	@if $(NET_RUNNING); then kill "$$(cat $(NET_PID))"; fi
	@rm -f $(PID) $(NET_PID)

reload:
	@$(MAKE) halt
	@$(MAKE) up

# Waits for both processes to exit, so a `make up` right after finds the SSH port free.
destroy:
	@for p in $(PID) $(NET_PID); do \
		pid=$$(cat $$p 2>/dev/null) || continue; \
		kill $$pid 2>/dev/null || continue; \
		for i in $$(seq 1 50); do kill -0 $$pid 2>/dev/null || break; sleep 0.1; done; \
	done
	rm -rf $(VM_DIR)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/$(CHECKSUM_NAME) | grep -F 'SHA256 ($(IMAGE_NAME)) =' \
		| awk '{ print $$NF "  $@" }' | shasum -a 256 -c

# Fedora publishes qcow2. A raw copy boots with krunkit's defaults and clones instantly.
$(RAW_IMAGE): $(IMAGE)
	qemu-img convert -O raw $< $@

# cp -c makes an APFS clone, so the 20 GiB disk only uses space for what the guest writes.
$(DISK): | $(RAW_IMAGE)
	mkdir -p $(VM_DIR)
	cp -c $(RAW_IMAGE) $@
	truncate -s $(DISK_SIZE) $@

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C krunkit-gpu -f $@

$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" -e "s|@UID@|$$(id -u)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed

purge:
	rm -f $(IMAGE) $(RAW_IMAGE)
