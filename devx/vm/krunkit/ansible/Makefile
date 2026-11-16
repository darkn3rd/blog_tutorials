SSH_PORT ?= 2222
HTTP_PORT ?= 8080
PROVISION ?= false
CPUS ?= 2
# krunkit takes memory in MiB.
MEMORY ?= 4096
DISK_SIZE ?= 20G

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE ?= images/$(IMAGE_NAME)
RAW_IMAGE := $(IMAGE:.img=.raw)

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
GUEST_IP := 192.168.127.2

# gvproxy isn't packaged on its own in Homebrew; Podman ships a copy.
GVPROXY ?= $(shell command -v gvproxy || echo $$(brew --prefix)/opt/podman/libexec/podman/gvproxy)

SSH := ssh -i $(KEY) -p $(SSH_PORT) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	ubuntu@127.0.0.1
RUNNING := { test -f $(PID) && kill -0 "$$(cat $(PID))"; } 2>/dev/null
NET_RUNNING := { test -f $(NET_PID) && kill -0 "$$(cat $(NET_PID))"; } 2>/dev/null

.DELETE_ON_ERROR:
.PHONY: up start network provision verify ssh status halt reload destroy purge

up: start
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

# gvproxy is the VM's network: DHCP, DNS, NAT and the port forwards to 127.0.0.1.
network:
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

start: $(DISK) $(SEED) network
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

# Ask the guest to power off over SSH, then krunkit's API, then kill krunkit.
halt:
	@if $(RUNNING); then \
		$(SSH) sudo systemctl poweroff >/dev/null 2>&1; \
		for i in $$(seq 1 60); do $(RUNNING) || break; sleep 1; done; \
		if $(RUNNING); then \
			echo "Guest did not shut down; stopping krunkit." >&2; \
			curl -fsS --unix-socket $(API) http://krunkit/vm/state -X POST -d '{"state":"Stop"}' >/dev/null; \
			for i in $$(seq 1 10); do $(RUNNING) || break; sleep 1; done; \
			if $(RUNNING); then kill "$$(cat $(PID))"; fi; \
		fi; \
	fi
	@if $(NET_RUNNING); then kill "$$(cat $(NET_PID))"; fi
	@rm -f $(PID) $(NET_PID)

reload:
	@$(MAKE) halt
	@$(MAKE) up

destroy:
	@if $(RUNNING); then kill "$$(cat $(PID))"; fi
	@if $(NET_RUNNING); then kill "$$(cat $(NET_PID))"; fi
	rm -rf $(VM_DIR)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

# Ubuntu publishes qcow2. A raw copy boots with krunkit's defaults and clones instantly.
$(RAW_IMAGE): $(IMAGE)
	qemu-img convert -O raw $< $@

# cp -c makes an APFS clone, so the 20 GiB disk only uses space for what the guest writes.
$(DISK): | $(RAW_IMAGE)
	mkdir -p $(VM_DIR)
	cp -c $(RAW_IMAGE) $@
	truncate -s $(DISK_SIZE) $@

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C krunkit-example -f $@

$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" -e "s|@UID@|$$(id -u)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed

purge:
	rm -f $(IMAGE) $(RAW_IMAGE)
