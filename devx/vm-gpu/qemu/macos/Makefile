CPUS ?= 2
MEMORY ?= 4096
DISK_SIZE ?= 20G
SSH_PORT ?= 2222

# How the guest gets a GPU:
#   virtio  a 2D virtio-gpu: a display adapter, no 3D, so the guest renders on its CPU
#   virgl   virtio-gpu with OpenGL forwarded to the Mac's GPU (needs a QEMU with OpenGL)
#   venus   virtio-gpu with Vulkan forwarded to the Mac's GPU (needs a QEMU with Venus)
# Homebrew's QEMU only has virtio; see the README for virgl and venus.
GPU ?= virtio
# The window of host memory that Venus maps GPU buffers through.
HOSTMEM ?= 4G

# Name for this VM in the benchmark results, and the llama.cpp release to build.
LABEL ?= qemu-$(GPU)
LLAMA_REF ?= master

# Fedora, for a recent kernel and Mesa.
FEDORA_RELEASE ?= 45
FEDORA_BUILD ?= 1.4
IMAGE_BASE_URL ?= https://download.fedoraproject.org/pub/fedora/linux/releases/$(FEDORA_RELEASE)/Cloud/aarch64/images
IMAGE_NAME := Fedora-Cloud-Base-Generic-$(FEDORA_RELEASE)-$(FEDORA_BUILD).aarch64.qcow2
CHECKSUM_NAME := Fedora-Cloud-$(FEDORA_RELEASE)-$(FEDORA_BUILD)-aarch64-CHECKSUM
IMAGE ?= images/$(IMAGE_NAME)

QEMU ?= qemu-system-aarch64
# UEFI firmware that comes with Homebrew's QEMU.
QEMU_SHARE ?= $(shell brew --prefix qemu 2>/dev/null)/share/qemu
EFI_CODE ?= $(QEMU_SHARE)/edk2-aarch64-code.fd
EFI_VARS ?= $(QEMU_SHARE)/edk2-arm-vars.fd

VM_DIR := $(CURDIR)/.vm
DISK := $(VM_DIR)/disk.qcow2
VARS := $(VM_DIR)/efi-vars.fd
SEED := $(VM_DIR)/seed.iso
KEY := $(VM_DIR)/id_ed25519
PID := $(VM_DIR)/qemu.pid
MODE := $(VM_DIR)/gpu

# The GPU part of the QEMU command line, for each mode.
GPU_ARGS_virtio := -device virtio-gpu-pci -display none
GPU_ARGS_virgl := -device virtio-gpu-gl-pci -display cocoa,gl=es
# Venus maps GPU memory into the guest as blobs, which needs guest RAM that QEMU can
# share with virglrenderer.
GPU_ARGS_venus := -object memory-backend-file,id=mem,size=$(MEMORY)M,mem-path=$(VM_DIR)/ram,share=on \
	-machine memory-backend=mem \
	-device virtio-gpu-gl-pci,blob=true,venus=true,hostmem=$(HOSTMEM) -display cocoa,gl=es

SSH_OPTS := -i $(KEY) -p $(SSH_PORT) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
SSH := ssh $(SSH_OPTS) fedora@127.0.0.1
RUNNING := { test -f $(PID) && kill -0 "$$(cat $(PID))"; } 2>/dev/null

.DELETE_ON_ERROR:
.PHONY: up check start sync gpu hwinfo gpu-check bench ssh status halt reload destroy purge

# Checks that this Mac and this QEMU can do what GPU asks for, before anything starts.
check:
	@test "$$(uname -m)" = arm64 || { echo "This project needs a Mac with Apple silicon." >&2; exit 1; }
	@test -f "$(EFI_CODE)" || { echo "No UEFI firmware at $(EFI_CODE); install QEMU with Homebrew, or set EFI_CODE and EFI_VARS." >&2; exit 1; }
	@case "$(GPU)" in \
	virtio) ;; \
	virgl|venus) \
		$(QEMU) -device help 2>/dev/null | grep -q '"virtio-gpu-gl-pci"' || { \
			echo "This QEMU ($$($(QEMU) --version | sed -n '1s/.*version //p')) has no OpenGL, so it has no virtio-gpu-gl-pci." >&2; \
			echo "GPU=$(GPU) needs a QEMU built with virglrenderer; see the README. GPU=virtio works with this one." >&2; exit 1; }; \
		if [ "$(GPU)" = venus ] && ! $(QEMU) -device virtio-gpu-gl-pci,help 2>/dev/null | grep -q venus; then \
			echo "This QEMU has no Venus support. It needs QEMU 9.2 or later, built with virglrenderer 1.0 or later with Venus." >&2; exit 1; \
		fi ;; \
	*) echo "Unknown GPU=$(GPU); use virtio, virgl or venus." >&2; exit 1 ;; \
	esac

up: $(DISK) $(VARS) $(SEED)
	@if [ "$$(cat $(MODE) 2>/dev/null)" != "$(GPU)" ]; then \
		echo "This VM was created with GPU=$$(cat $(MODE)); run make destroy first, or pass GPU=$$(cat $(MODE))." >&2; exit 1; \
	fi
	@if $(RUNNING); then echo "VM is already running."; else $(MAKE) --no-print-directory start; fi
	@echo "Waiting for SSH on 127.0.0.1:$(SSH_PORT)..."
	@for i in $$(seq 1 90); do \
		$(SSH) true 2>/dev/null && break; \
		$(RUNNING) || { echo "QEMU exited; see $(VM_DIR)/qemu.log and console.log" >&2; tail -5 $(VM_DIR)/qemu.log >&2; exit 1; }; \
		if [ "$$i" = 90 ]; then echo "SSH did not come up; see $(VM_DIR)/console.log" >&2; exit 1; fi; \
		sleep 2; \
	done
	@echo "Waiting for cloud-init to install the packages..."
	@# Fedora lets only root read cloud-init's state; as another user, --wait never ends.
	@$(SSH) sudo cloud-init status --wait >/dev/null
	@$(MAKE) --no-print-directory sync

# Starts QEMU in the background with Apple's Hypervisor framework (hvf). The serial
# console goes to console.log, and SSH is forwarded from 127.0.0.1:SSH_PORT with QEMU's
# user-mode network. virgl and venus open a window, so QEMU can't detach from the
# terminal for them and runs as a background job instead.
start: check
	@if lsof -nP -iTCP:$(SSH_PORT) -sTCP:LISTEN >/dev/null; then \
		echo "Port $(SSH_PORT) is in use; pick another with SSH_PORT=...:" >&2; \
		lsof -nP -iTCP:$(SSH_PORT) -sTCP:LISTEN >&2; exit 1; \
	fi
	@args="-name dev -machine virt,accel=hvf,highmem=on -cpu host -smp $(CPUS) -m $(MEMORY) \
		-drive if=pflash,format=raw,readonly=on,file=$(EFI_CODE) \
		-drive if=pflash,format=raw,file=$(VARS) \
		-drive if=virtio,format=qcow2,file=$(DISK) \
		-drive if=virtio,format=raw,readonly=on,file=$(SEED) \
		-netdev user,id=net0,hostfwd=tcp:127.0.0.1:$(SSH_PORT)-:22 \
		-device virtio-net-pci,netdev=net0 \
		-device virtio-rng-pci \
		$(GPU_ARGS_$(GPU)) \
		-serial file:$(VM_DIR)/console.log -monitor none -pidfile $(PID) -D $(VM_DIR)/qemu.log"; \
	if [ "$(GPU)" = virtio ]; then \
		$(QEMU) $$args -daemonize 2>>$(VM_DIR)/qemu.log || { cat $(VM_DIR)/qemu.log >&2; exit 1; }; \
	else \
		nohup $(QEMU) $$args </dev/null >>$(VM_DIR)/qemu.log 2>&1 & \
		for i in $$(seq 1 50); do $(RUNNING) && break; sleep 0.1; done; \
		$(RUNNING) || { cat $(VM_DIR)/qemu.log >&2; exit 1; }; \
	fi

sync:
	@rsync -a --delete --exclude /.vm/ --exclude /images/ --exclude /results/ \
		-e "ssh $(SSH_OPTS)" ./ fedora@127.0.0.1:/workspace/

# The full report of the virtual hardware the guest sees, GPU included, from hwinfo.sh.
# HWINFO_ARGS=--tsv prints raw section/field/value rows instead of Markdown.
hwinfo: sync
	@$(SSH) 'sudo /workspace/hwinfo.sh $(HWINFO_ARGS)'

# Checks the guest for what the GPU needs: kernel options, driver, virtio-gpu features
# such as blob_alignment, device node permissions and Mesa, from gpu-check.sh.
gpu-check: sync
	@$(SSH) '/workspace/gpu-check.sh'

# What the guest sees: its GPUs, and the Vulkan and OpenGL devices.
gpu:
	@$(SSH) 'lspci -nnk | grep -A2 -iE "vga|3d|display"; \
		echo; ls -l /dev/dri; \
		echo; sudo dmesg | grep -E "\[drm\] (features|cap set)" || true; \
		echo; vulkaninfo --summary 2>&1 | grep -E "deviceName|driverName|ERROR" || true; \
		echo; eglinfo -B -p surfaceless 2>/dev/null | grep -E "renderer" || true'

# Builds llama-bench in the guest, runs it, and copies the results back to results/.
bench: sync
	@$(SSH) 'LABEL=$(LABEL) LLAMA_REF=$(LLAMA_REF) RESULTS=/workspace/results /workspace/gpu-bench.sh'; \
	rc=$$?; mkdir -p results; \
	rsync -a -e "ssh $(SSH_OPTS)" fedora@127.0.0.1:/workspace/results/ results/; \
	exit $$rc

ssh:
	@$(SSH) -t 'cd /workspace && exec bash -l'

status:
	@if $(RUNNING); then \
		echo "running (pid $$(cat $(PID))), GPU $$(cat $(MODE)), ssh 127.0.0.1:$(SSH_PORT)"; \
	elif [ -f $(DISK) ]; then \
		echo "stopped, GPU $$(cat $(MODE))"; \
	else \
		echo "not created"; \
	fi

halt:
	@if $(RUNNING); then \
		$(SSH) sudo systemctl poweroff 2>/dev/null || true; \
		for i in $$(seq 1 60); do $(RUNNING) || break; sleep 1; done; \
		if $(RUNNING); then echo "Guest did not shut down; stopping QEMU." >&2; kill "$$(cat $(PID))"; sleep 2; fi; \
	fi
	@rm -f $(PID)

reload:
	@$(MAKE) --no-print-directory halt
	@$(MAKE) --no-print-directory up

# Stops QEMU and deletes .vm/, keeping the downloaded image. Waits for QEMU to exit, so
# a `make up` right after finds the SSH port free.
destroy:
	@if $(RUNNING); then \
		pid=$$(cat $(PID)); kill $$pid; \
		for i in $$(seq 1 50); do kill -0 $$pid 2>/dev/null || break; sleep 0.1; done; \
	fi
	rm -rf $(VM_DIR)

purge:
	rm -f $(IMAGE)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/$(CHECKSUM_NAME) | grep -F 'SHA256 ($(IMAGE_NAME)) =' \
		| awk '{ print $$NF "  $@" }' | shasum -a 256 -c

# The disk is a copy-on-write overlay on the cloud image, so it only uses space for
# what the guest writes. The GPU mode is recorded with it, since cloud-init has
# already set up the guest by the time it would change.
$(DISK): | $(IMAGE)
	mkdir -p $(VM_DIR)
	qemu-img create -q -f qcow2 -F qcow2 -b $(abspath $(IMAGE)) $@ $(DISK_SIZE)
	echo $(GPU) > $(MODE)

# Each VM keeps its own copy of the UEFI variables.
$(VARS):
	mkdir -p $(VM_DIR)
	cp $(EFI_VARS) $@

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C qemu-gpu -f $@

$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed
