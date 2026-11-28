SSH_PORT ?= 2222
HTTP_PORT ?= 8080
PROVISION ?= false
CPUS ?= 2
# vfkit takes memory in MiB.
MEMORY ?= 4096
DISK_SIZE ?= 20G

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
# The guest runs the same architecture as the Mac, and Ubuntu names its images for it.
ARCH := $(shell uname -m)
ifeq ($(ARCH),arm64)
IMAGE_ARCH := arm64
else ifeq ($(ARCH),x86_64)
IMAGE_ARCH := amd64
else
$(error Unsupported architecture $(ARCH))
endif
IMAGE_NAME := ubuntu-26.04-server-cloudimg-$(IMAGE_ARCH).img
IMAGE ?= images/$(IMAGE_NAME)
RAW_IMAGE := $(IMAGE:.img=.raw)

VM_DIR := $(CURDIR)/.vm
DISK := $(VM_DIR)/disk.raw
VARS := $(VM_DIR)/efi-vars.fd
USER_DATA := $(VM_DIR)/cloud-init/user-data
META_DATA := $(VM_DIR)/cloud-init/meta-data
KEY := $(VM_DIR)/id_ed25519
PID := $(VM_DIR)/vfkit.pid
API := $(VM_DIR)/vfkit.sock
NET_PID := $(VM_DIR)/gvproxy.pid
NET_SOCK := $(VM_DIR)/net.sock
NET_API := $(VM_DIR)/gvproxy.sock

# gvproxy gives the guest 192.168.127.2 for this MAC address.
GUEST_MAC := 5a:94:ef:e4:0c:ee
GUEST_IP := 192.168.127.2

# Use vfkit and gvproxy from the PATH, then the copies Podman ships, and otherwise download
# the releases into bin/. Podman's Homebrew formula is Apple Silicon only, so on an Intel Mac
# the download is the way to get them. Both releases are universal binaries.
PODMAN_LIBEXEC = $(shell brew --prefix 2>/dev/null)/opt/podman/libexec/podman
BIN_DIR := bin
VFKIT ?= $(shell command -v vfkit || { test -x $(PODMAN_LIBEXEC)/vfkit && echo $(PODMAN_LIBEXEC)/vfkit; } || echo $(BIN_DIR)/vfkit)
GVPROXY ?= $(shell command -v gvproxy || { test -x $(PODMAN_LIBEXEC)/gvproxy && echo $(PODMAN_LIBEXEC)/gvproxy; } || echo $(BIN_DIR)/gvproxy)

VFKIT_VERSION := v0.6.4
VFKIT_URL := https://github.com/crc-org/vfkit/releases/download/$(VFKIT_VERSION)/vfkit
# vfkit publishes no checksums, so this is the SHA-256 of the v0.6.4 release file.
VFKIT_SHA256 := 0ed83fc8ca7aa708598835480dba1362406aa7cd1dab3b27464eb76327d9652d
GVPROXY_VERSION := v0.9.1
GVPROXY_URL := https://github.com/containers/gvisor-tap-vsock/releases/download/$(GVPROXY_VERSION)

SSH := ssh -i $(KEY) -p $(SSH_PORT) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	ubuntu@127.0.0.1
RUNNING := { test -f $(PID) && kill -0 "$$(cat $(PID))"; } 2>/dev/null
NET_RUNNING := { test -f $(NET_PID) && kill -0 "$$(cat $(NET_PID))"; } 2>/dev/null
# Stop the process in a PID file and wait for it to exit. vfkit keeps running for a moment
# after SIGTERM, and when it exits it deletes its API socket, even one a newer VM made.
STOP = pid=$$(cat $(1)); kill $$pid; \
	for i in $$(seq 1 50); do kill -0 $$pid 2>/dev/null || break; sleep 0.2; done; \
	kill -0 $$pid 2>/dev/null && kill -9 $$pid || true

.DELETE_ON_ERROR:
.PHONY: up start network provision verify ssh status halt reload destroy purge

up: start
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

# gvproxy is the VM's network: DHCP, DNS, NAT and the port forwards to 127.0.0.1.
network: $(GVPROXY)
	@if ! $(NET_RUNNING); then \
		mkdir -p $(VM_DIR); \
		rm -f $(NET_SOCK) $(NET_API); \
		$(GVPROXY) -listen-vfkit unixgram://$(NET_SOCK) -listen unix://$(NET_API) \
			-ssh-port $(SSH_PORT) -pid-file $(NET_PID) -log-file $(VM_DIR)/gvproxy.log \
			</dev/null >/dev/null 2>&1 & \
		for i in $$(seq 1 50); do test -S $(NET_API) && break; sleep 0.1; done; \
		test -S $(NET_API) || { echo "gvproxy did not start; see $(VM_DIR)/gvproxy.log" >&2; exit 1; }; \
		curl -fsS --unix-socket $(NET_API) http://gvproxy/services/forwarder/expose -X POST \
			-d '{"local":"127.0.0.1:$(HTTP_PORT)","remote":"$(GUEST_IP):80"}'; \
	fi

# vfkit creates the EFI variable store on the first boot and keeps it after that.
# --cloud-init builds the seed disk from user-data and meta-data each time it starts.
start: $(VFKIT) $(DISK) $(USER_DATA) $(META_DATA) network
	@if $(RUNNING); then \
		echo "VM is already running."; \
	else \
		rm -f $(API); \
		create=; test -f $(VARS) || create=,create; \
		$(VFKIT) --cpus $(CPUS) --memory $(MEMORY) \
			--bootloader efi,variable-store=$(VARS)$$create \
			--cloud-init $(USER_DATA),$(META_DATA) \
			--device virtio-blk,path=$(DISK) \
			--device virtio-net,unixSocketPath=$(NET_SOCK),mac=$(GUEST_MAC) \
			--device virtio-fs,sharedDir=$(CURDIR),mountTag=workspace \
			--device virtio-serial,logFilePath=$(VM_DIR)/console.log \
			--device virtio-rng \
			--restful-uri unix://$(API) --pidfile $(PID) \
			</dev/null >$(VM_DIR)/vfkit.log 2>&1 & \
		for i in $$(seq 1 50); do $(RUNNING) && break; sleep 0.1; done; \
	fi
	@echo "Waiting for SSH..."
	@for i in $$(seq 1 60); do \
		$(SSH) true 2>/dev/null && break; \
		if [ "$$i" = 60 ]; then echo "SSH did not come up; see $(VM_DIR)/console.log and vfkit.log" >&2; exit 1; fi; \
		sleep 2; \
	done
	@echo "Waiting for cloud-init..."
	@$(SSH) cloud-init status --wait >/dev/null

provision:
	ansible-playbook -e ansible_port=$(SSH_PORT) playbook.yaml

verify:
	curl --include --fail http://localhost:$(HTTP_PORT)

ssh:
	$(SSH) -t 'cd /workspace && exec bash -l'

status:
	@if $(RUNNING); then \
		echo "running (pid $$(cat $(PID))), ssh 127.0.0.1:$(SSH_PORT), http 127.0.0.1:$(HTTP_PORT)"; \
	elif [ -f $(DISK) ]; then \
		echo "stopped"; \
	else \
		echo "not created"; \
	fi

# "Stop" asks the guest to shut down; "HardStop" stops the VM without asking.
halt:
	@if $(RUNNING); then \
		curl -fsS --unix-socket $(API) http://vfkit/vm/state -X POST -d '{"state":"Stop"}' >/dev/null; \
		for i in $$(seq 1 60); do $(RUNNING) || break; sleep 1; done; \
		if $(RUNNING); then \
			echo "Guest did not shut down; stopping vfkit." >&2; \
			curl -fsS --unix-socket $(API) http://vfkit/vm/state -X POST -d '{"state":"HardStop"}' >/dev/null; \
			for i in $$(seq 1 10); do $(RUNNING) || break; sleep 1; done; \
			if $(RUNNING); then $(call STOP,$(PID)); fi; \
		fi; \
	fi
	@if $(NET_RUNNING); then $(call STOP,$(NET_PID)); fi
	@rm -f $(PID) $(NET_PID)

reload:
	@$(MAKE) halt
	@$(MAKE) up

destroy:
	@if $(RUNNING); then $(call STOP,$(PID)); fi
	@if $(NET_RUNNING); then $(call STOP,$(NET_PID)); fi
	rm -rf $(VM_DIR)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

# Ubuntu publishes qcow2, and the Virtualization framework only reads raw disks.
$(RAW_IMAGE): $(IMAGE)
	qemu-img convert -O raw $< $@

# cp -c makes an APFS clone, so the 20 GiB disk only uses space for what the guest writes.
$(DISK): | $(RAW_IMAGE)
	mkdir -p $(VM_DIR)
	cp -c $(RAW_IMAGE) $@
	truncate -s $(DISK_SIZE) $@

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C vfkit-example -f $@

$(USER_DATA): cloud-init/user-data | $(KEY)
	mkdir -p $(dir $@)
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" -e "s|@UID@|$$(id -u)|" $< > $@

$(META_DATA): cloud-init/meta-data
	mkdir -p $(dir $@)
	cp $< $@

$(BIN_DIR)/vfkit:
	mkdir -p $(BIN_DIR)
	curl -fL --progress-bar -o $@ $(VFKIT_URL)
	echo "$(VFKIT_SHA256)  $@" | shasum -a 256 -c
	chmod +x $@

# The release isn't signed, and Apple Silicon won't run unsigned code, so sign it ad hoc.
$(BIN_DIR)/gvproxy:
	mkdir -p $(BIN_DIR)
	curl -fL --progress-bar -o $@ $(GVPROXY_URL)/gvproxy-darwin
	curl -fsSL $(GVPROXY_URL)/sha256sums | grep ' gvproxy-darwin$$' | sed 's|gvproxy-darwin|$@|' | shasum -a 256 -c
	chmod +x $@
	codesign --force -s - $@

purge:
	rm -f $(IMAGE) $(RAW_IMAGE) $(BIN_DIR)/vfkit $(BIN_DIR)/gvproxy
