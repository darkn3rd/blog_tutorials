SSH_PORT ?= 2222
HTTP_PORT ?= 8080
PROVISION ?= false
CPUS ?= 2
MEMORY ?= 4G
DISK_SIZE ?= 20G

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE ?= images/$(IMAGE_NAME)

VM_DIR := .vm
DISK := $(VM_DIR)/disk.qcow2
VARS := $(VM_DIR)/efi-vars.fd
SEED := $(VM_DIR)/seed.iso
KEY := $(VM_DIR)/id_ed25519
PID := $(VM_DIR)/qemu.pid
MONITOR := $(VM_DIR)/monitor.sock

FIRMWARE_DIR := $(shell brew --prefix qemu)/share/qemu

SSH := ssh -i $(KEY) -p $(SSH_PORT) -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	ubuntu@127.0.0.1
RUNNING := test -f $(PID) && kill -0 "$$(cat $(PID))" 2>/dev/null

.DELETE_ON_ERROR:
.PHONY: up start provision verify ssh status halt destroy purge

up: start
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

start: $(DISK) $(VARS) $(SEED)
	@if $(RUNNING); then \
		echo "VM is already running."; \
	else \
		qemu-system-aarch64 \
			-machine virt -accel hvf -cpu host \
			-smp $(CPUS) -m $(MEMORY) \
			-drive if=pflash,format=raw,readonly=on,file=$(FIRMWARE_DIR)/edk2-aarch64-code.fd \
			-drive if=pflash,format=raw,file=$(VARS) \
			-drive if=virtio,format=qcow2,file=$(DISK) \
			-drive if=virtio,format=raw,readonly=on,file=$(SEED) \
			-nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$(SSH_PORT)-:22,hostfwd=tcp:127.0.0.1:$(HTTP_PORT)-:80 \
			-virtfs local,path=$(CURDIR),mount_tag=workspace,security_model=none \
			-monitor unix:$(MONITOR),server,nowait \
			-serial file:$(VM_DIR)/console.log \
			-display none -daemonize -pidfile $(PID); \
	fi
	@echo "Waiting for SSH..."
	@for i in $$(seq 1 60); do \
		$(SSH) true 2>/dev/null && break; \
		if [ "$$i" = 60 ]; then echo "SSH did not come up; see $(VM_DIR)/console.log" >&2; exit 1; fi; \
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

halt:
	@if $(RUNNING); then \
		echo system_powerdown | nc -U -w 1 $(MONITOR) >/dev/null; \
		for i in $$(seq 1 60); do $(RUNNING) || exit 0; sleep 1; done; \
		echo "Guest did not shut down; stopping QEMU." >&2; \
		echo quit | nc -U -w 1 $(MONITOR) >/dev/null; \
	fi

destroy:
	@if $(RUNNING); then kill "$$(cat $(PID))"; fi
	rm -rf $(VM_DIR)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

$(DISK): | $(IMAGE)
	mkdir -p $(VM_DIR)
	qemu-img create -q -f qcow2 -F qcow2 -b $(abspath $(IMAGE)) $@ $(DISK_SIZE)

$(VARS):
	mkdir -p $(VM_DIR)
	cp $(FIRMWARE_DIR)/edk2-arm-vars.fd $@

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C qemu-example -f $@

$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" -e "s|@UID@|$$(id -u)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed

purge:
	rm -f $(IMAGE)
