CPUS ?= 2
MEMORY ?= 4G
DISK_SIZE ?= 20G
PROVISION ?= false

# HyperKit's last commit, from February 2022.
HYPERKIT_REPO ?= https://github.com/moby/hyperkit.git
HYPERKIT_REF ?= 3cb0d5475244761c61e6fd4a562702c26b46f846
HYPERKIT_SRC := build/hyperkit-src
HYPERKIT := build/hyperkit

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-amd64.img
IMAGE ?= images/$(IMAGE_NAME)
KERNEL := images/ubuntu-26.04-server-cloudimg-amd64-vmlinuz-generic
INITRD := images/ubuntu-26.04-server-cloudimg-amd64-initrd-generic

VM_DIR := .vm
DISK := $(VM_DIR)/disk.raw
SEED := $(VM_DIR)/seed.iso
KEY := $(VM_DIR)/id_ed25519
PID := $(VM_DIR)/hyperkit.pid
CONSOLE := $(VM_DIR)/console.log

# The UUID decides the guest's MAC address.
UUID := 6a1e2f4c-0b3d-4a5e-8c7f-1d2e3f405162
HOSTNAME := dev

# macOS's DHCP server records every lease it hands out. The guest asks twice, with different
# client IDs, and old leases stay in the file, so take the newest one under its hostname.
LEASES := /var/db/dhcpd_leases
FIND_IP := awk '$$0 == "{" {n = ip = l = ""} \
	/^[ \t]*name=/ {n = $$0; sub(/.*=/, "", n)} \
	/^[ \t]*ip_address=/ {ip = $$0; sub(/.*=/, "", ip)} \
	/^[ \t]*lease=/ {l = $$0; sub(/.*=/, "", l)} \
	$$0 == "}" {if (n == "$(HOSTNAME)" && l "" > best "") {best = l ""; found = ip}} \
	END {print found}' $(LEASES) 2>/dev/null
IP = $(shell $(FIND_IP))

SSH_OPTS := -i $(KEY) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
# make expands a whole recipe before running any of it, so $(IP) would be looked up before
# the VM starts. SSH asks the shell for the address when the command runs.
SSH = ssh $(SSH_OPTS) ubuntu@$$($(FIND_IP))
# HyperKit, which runs as root, creates the PID file itself and refuses one that exists, so the
# start target removes a stale one. kill -0 would fail on a root process; ps can read it.
RUNNING := test -s $(PID) && ps -p "$$(cat $(PID))" >/dev/null 2>&1
# Ask HyperKit to exit, and force it to if it hasn't after 10 seconds.
KILL := sudo kill "$$(cat $(PID))"; \
	for i in $$(seq 1 10); do $(RUNNING) || break; sleep 1; done; \
	if $(RUNNING); then sudo kill -9 "$$(cat $(PID))"; fi

.DELETE_ON_ERROR:
.PHONY: up start provision verify url ssh status halt reload destroy purge

up: start
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

start: $(HYPERKIT) $(KERNEL) $(INITRD) $(DISK) $(SEED)
	@if $(RUNNING); then \
		echo "VM is already running."; \
	else \
		echo "Starting HyperKit; sudo may ask for your password."; \
		sudo -v || exit 1; \
		rm -f $(PID); \
		touch $(CONSOLE); \
		( sudo script -q $(CONSOLE) $(HYPERKIT) -A -c $(CPUS) -m $(MEMORY) -U $(UUID) -F $(PID) \
			-s 0:0,hostbridge -s 31,lpc -l com1,stdio \
			-s 2:0,virtio-net -s 3,virtio-blk,$(DISK) -s 4,ahci-cd,$(SEED) \
			-f kexec,$(KERNEL),$(INITRD),"root=LABEL=cloudimg-rootfs ro console=ttyS0 tsc=reliable" \
			</dev/null >/dev/null 2>&1 & ); \
	fi
	@echo "Waiting for SSH..."
	@for i in $$(seq 1 90); do \
		ip=$$($(FIND_IP)); \
		[ -n "$$ip" ] && ssh $(SSH_OPTS) ubuntu@$$ip true 2>/dev/null && break; \
		if [ "$$i" = 90 ]; then echo "SSH did not come up; see $(CONSOLE)" >&2; exit 1; fi; \
		sleep 2; \
	done
	@echo "Waiting for cloud-init..."
	@$(SSH) cloud-init status --wait >/dev/null

provision:
	@test -n "$(IP)" || { echo "No address for the VM; is it running?" >&2; exit 1; }
	ansible-playbook -e ansible_host=$(IP) playbook.yaml

verify:
	@test -n "$(IP)" || { echo "No address for the VM; is it running?" >&2; exit 1; }
	curl --include --fail --max-time 10 http://$(IP)

url:
	@test -n "$(IP)" || { echo "No address for the VM; is it running?" >&2; exit 1; }
	@echo http://$(IP)

ssh:
	@test -n "$(IP)" || { echo "No address for the VM; is it running?" >&2; exit 1; }
	$(SSH) -t

status:
	@if $(RUNNING); then \
		echo "running (pid $$(cat $(PID))), address $(IP)"; \
	elif [ -f $(DISK) ]; then \
		echo "stopped"; \
	else \
		echo "not created"; \
	fi

halt:
	@if $(RUNNING); then \
		$(SSH) sudo poweroff >/dev/null 2>&1 || true; \
		for i in $$(seq 1 60); do $(RUNNING) || exit 0; sleep 1; done; \
		echo "Guest did not shut down; stopping HyperKit." >&2; \
		$(KILL); \
	fi

reload:
	@$(MAKE) halt
	@$(MAKE) up

destroy:
	@if $(RUNNING); then $(KILL); fi
	rm -rf $(VM_DIR)

# HyperKit isn't in Homebrew, so build it. Its own build signs it with the hypervisor
# entitlement. -w because current clang rejects the old code's warnings.
$(HYPERKIT):
	@test "$$(uname -m)" = x86_64 || { echo "HyperKit only runs on Intel Macs." >&2; exit 1; }
	mkdir -p build
	test -d $(HYPERKIT_SRC) || git clone -q $(HYPERKIT_REPO) $(HYPERKIT_SRC)
	git -C $(HYPERKIT_SRC) checkout -q $(HYPERKIT_REF)
	$(MAKE) -C $(HYPERKIT_SRC) clean >/dev/null
	$(MAKE) -C $(HYPERKIT_SRC) CFLAGS_WARN=-w
	cp $(HYPERKIT_SRC)/build/hyperkit $@

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

# HyperKit boots the kernel directly, so it needs them as separate files.
$(KERNEL) $(INITRD):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/unpacked/$(notdir $@)
	curl -fsSL $(IMAGE_BASE_URL)/unpacked/SHA256SUMS | grep ' \*$(notdir $@)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

# Ubuntu publishes qcow2, and HyperKit only reads raw disks. The guest grows its filesystem
# into the extra space on first boot.
$(DISK): $(IMAGE)
	mkdir -p $(VM_DIR)
	qemu-img convert -O raw $< $@
	qemu-img resize -f raw -q $@ $(DISK_SIZE)

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C hyperkit-example -f $@

$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed

purge:
	rm -rf images build
