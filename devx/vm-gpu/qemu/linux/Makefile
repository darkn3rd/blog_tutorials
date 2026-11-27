SHELL := /bin/bash

CPUS ?= 2
MEMORY ?= 4096
DISK_SIZE ?= 20G
SSH_PORT ?= 2222

# How the guest gets a GPU:
#   virgl        virtio-gpu with OpenGL forwarded to the host's GPU, no Vulkan
#   venus        virtio-gpu with Vulkan forwarded to the host's GPU
#   gvtg         a slice of an Intel iGPU (GVT-g), with Intel's own Vulkan driver
#   passthrough  a whole GPU, given to the guest with VFIO; set PCI too
GPU ?= virgl
# The host GPU that virgl and venus render on.
RENDERNODE ?= /dev/dri/renderD128
# The window of host memory that Venus maps GPU buffers through.
HOSTMEM ?= 4G
# For passthrough: every PCI function of the GPU, comma-separated, as lspci shows them,
# such as 01:00.0,01:00.1 for a card and its HDMI audio.
PCI ?=
# For gvtg: the Intel iGPU, the vGPU type (see `make check GPU=gvtg`) and the vGPU's id.
GVT_PCI ?= 0000:00:02.0
GVT_TYPE ?= i915-GVTg_V5_4
GVT_UUID ?= 6f3b1d6e-3c1a-4a9e-9a43-6d2c0e2f5a10

# Name for this VM in the benchmark results, and the llama.cpp release to build.
LABEL ?= qemu-$(GPU)
LLAMA_REF ?= master

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-amd64.img
IMAGE ?= images/$(IMAGE_NAME)

# UEFI firmware: Debian and Ubuntu (ovmf), then Fedora (edk2-ovmf).
OVMF_CODE ?= $(firstword $(wildcard /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/ovmf/OVMF_CODE.fd))
OVMF_VARS ?= $(firstword $(wildcard /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd /usr/share/edk2/ovmf/OVMF_VARS.fd))

QEMU ?= qemu-system-x86_64

VM_DIR := $(CURDIR)/.vm
DISK := $(VM_DIR)/disk.qcow2
VARS := $(VM_DIR)/OVMF_VARS.fd
SEED := $(VM_DIR)/seed.img
KEY := $(VM_DIR)/id_ed25519
PID := $(VM_DIR)/qemu.pid
MODE := $(VM_DIR)/gpu

comma := ,
# Full addresses, such as 0000:01:00.0, for sysfs.
SYSFS_PCI = $(foreach a,$(subst $(comma), ,$(PCI)),$(if $(filter 3,$(words $(subst :, ,$(a)))),$(a),0000:$(a)))

# The GPU part of the QEMU command line, for each mode.
GPU_ARGS_virgl := -device virtio-vga-gl -display egl-headless,rendernode=$(RENDERNODE)
# Venus maps GPU memory into the guest as blobs, which needs guest RAM that QEMU can
# share with virglrenderer.
GPU_ARGS_venus := -object memory-backend-memfd,id=mem,size=$(MEMORY)M,share=on \
	-machine memory-backend=mem \
	-device virtio-vga-gl,blob=true,venus=true,hostmem=$(HOSTMEM) \
	-display egl-headless,rendernode=$(RENDERNODE)
# The vGPU only renders; a plain virtio-vga stays the guest's display adapter.
GPU_ARGS_gvtg := -device virtio-vga -display none \
	-device vfio-pci,sysfsdev=/sys/bus/mdev/devices/$(GVT_UUID),display=off
# No virtual display adapter: the passed-through GPU is the only one.
GPU_ARGS_passthrough := -vga none -display none $(foreach a,$(SYSFS_PCI),-device vfio-pci,host=$(a))

# VFIO pins guest memory, which needs root's memory-lock limit and access to
# /dev/vfio. For gvtg and passthrough QEMU starts as root with no lock limit and
# switches to you once the devices are open.
RUNAS_FLAG := $(shell $(QEMU) -help 2>/dev/null | grep -q '^-run-with' && echo '-run-with user=$(USER)' || echo '-runas $(USER)')
ifneq ($(filter $(GPU),gvtg passthrough),)
LAUNCH := sudo prlimit --memlock=unlimited:unlimited $(QEMU) $(RUNAS_FLAG)
else
LAUNCH := $(QEMU)
endif

SSH_OPTS := -i $(KEY) -p $(SSH_PORT) -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
SSH := ssh $(SSH_OPTS) ubuntu@127.0.0.1
RUNNING := { test -f $(PID) && kill -0 "$$(cat $(PID))"; } 2>/dev/null

.DELETE_ON_ERROR:
.PHONY: up check start sync gpu hwinfo bench ssh status halt reload destroy purge \
	vfio-bind vfio-unbind vgpu vgpu-remove

# Checks that the host can do what GPU asks for, before anything starts.
check:
	@test -w /dev/kvm || { echo "Can't open /dev/kvm; add yourself to the kvm group and log in again." >&2; exit 1; }
	@test -n "$(OVMF_CODE)" || { echo "No UEFI firmware found; install ovmf, or set OVMF_CODE and OVMF_VARS." >&2; exit 1; }
	@case "$(GPU)" in \
	virgl|venus) \
		test -e $(RENDERNODE) || { echo "$(RENDERNODE) doesn't exist; set RENDERNODE to a host GPU (ls /dev/dri)." >&2; exit 1; }; \
		test -r $(RENDERNODE) -a -w $(RENDERNODE) || { echo "You can't open $(RENDERNODE); add yourself to the render group and log in again." >&2; exit 1; }; \
		echo "Host GPU: $(RENDERNODE) ($$(basename $$(readlink -f /sys/class/drm/$$(basename $(RENDERNODE))/device/driver)))"; \
		$(QEMU) -device help 2>/dev/null | grep -q '"virtio-vga-gl"' || { echo "This QEMU has no OpenGL support. On Ubuntu 24.04 and later, install qemu-system-modules-opengl." >&2; exit 1; }; \
		if [ "$(GPU)" = venus ] && ! $(QEMU) -device virtio-vga-gl,help 2>/dev/null | grep -q venus; then \
			echo "This QEMU ($$($(QEMU) --version | sed -n '1s/.*version //p')) has no Venus support. It needs QEMU 9.2 or later, built with virglrenderer 1.0 or later." >&2; exit 1; \
		fi ;; \
	gvtg) \
		types=/sys/bus/pci/devices/$(GVT_PCI)/mdev_supported_types; \
		test -d $$types || { \
			echo "$(GVT_PCI) offers no GVT-g vGPUs. GVT-g works on Intel iGPUs from Broadwell to Comet Lake (5th to 10th gen Core)." >&2; \
			echo "Turn it on: add i915.enable_gvt=1 and intel_iommu=on to the kernel command line, load the kvmgt module at boot (echo kvmgt | sudo tee /etc/modules-load.d/kvmgt.conf), and reboot." >&2; exit 1; }; \
		for t in $$types/*; do printf '  %-18s %s vGPUs left, %s\n' $$(basename $$t) $$(cat $$t/available_instances) "$$(tr '\n' ' ' < $$t/description)"; done; \
		test -d $$types/$(GVT_TYPE) || { echo "No vGPU type $(GVT_TYPE); set GVT_TYPE to one above." >&2; exit 1; }; \
		test -e /sys/bus/mdev/devices/$(GVT_UUID) || echo "The vGPU doesn't exist yet; make up creates it with sudo (make vgpu)." ;; \
	passthrough) \
		test -n "$(PCI)" || { echo "Set PCI to the GPU's PCI functions, such as PCI=01:00.0,01:00.1 (see: lspci -nn | grep -iE 'vga|3d|display|audio')." >&2; exit 1; }; \
		test -d /sys/kernel/iommu_groups/0 || { echo "The IOMMU is off. Turn on VT-d or AMD-Vi in the firmware, and add intel_iommu=on to the kernel command line on Intel." >&2; exit 1; }; \
		for a in $(SYSFS_PCI); do \
			test -e /sys/bus/pci/devices/$$a || { echo "No PCI device $$a." >&2; exit 1; }; \
			lspci -nnk -s $$a | head -3; \
			echo "  IOMMU group $$(basename $$(readlink /sys/bus/pci/devices/$$a/iommu_group)):" \
				$$(ls /sys/bus/pci/devices/$$a/iommu_group/devices); \
		done; \
		echo "Every device in those IOMMU groups has to go to the guest, or QEMU won't start." ;; \
	*) echo "Unknown GPU=$(GPU); use virgl, venus, gvtg or passthrough." >&2; exit 1 ;; \
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
	@$(SSH) cloud-init status --wait >/dev/null
	@$(MAKE) --no-print-directory sync

# Starts QEMU in the background. The serial console goes to console.log, and SSH is
# forwarded from 127.0.0.1:SSH_PORT with QEMU's user-mode network, so nothing here
# needs root except VFIO.
start: check
	@if ss -Htln "sport = :$(SSH_PORT)" | grep -q .; then \
		echo "Port $(SSH_PORT) is in use; pick another with SSH_PORT=..." >&2; exit 1; \
	fi
	@if [ "$(GPU)" = gvtg ]; then $(MAKE) --no-print-directory vgpu; fi
	@if [ "$(GPU)" = passthrough ]; then $(MAKE) --no-print-directory vfio-bind; fi
	$(LAUNCH) -name dev -machine q35,accel=kvm -cpu host -smp $(CPUS) -m $(MEMORY) \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) \
		-drive if=pflash,format=raw,file=$(VARS) \
		-drive if=virtio,format=qcow2,file=$(DISK) \
		-drive if=virtio,format=raw,readonly=on,file=$(SEED) \
		-netdev user,id=net0,hostfwd=tcp:127.0.0.1:$(SSH_PORT)-:22 \
		-device virtio-net-pci,netdev=net0 \
		-device virtio-rng-pci \
		$(GPU_ARGS_$(GPU)) \
		-serial file:$(VM_DIR)/console.log -monitor none \
		-daemonize -pidfile $(PID) -D $(VM_DIR)/qemu.log 2>>$(VM_DIR)/qemu.log \
		|| { cat $(VM_DIR)/qemu.log >&2; exit 1; }

sync:
	@rsync -a --delete --exclude /.vm/ --exclude /images/ --exclude /results/ \
		-e "ssh $(SSH_OPTS)" ./ ubuntu@127.0.0.1:/workspace/

# The full report of the virtual hardware the guest sees, GPU included, from hwinfo.sh.
# HWINFO_ARGS=--tsv prints raw section/field/value rows instead of Markdown.
hwinfo: sync
	@$(SSH) 'sudo /workspace/hwinfo.sh $(HWINFO_ARGS)'

# What the guest sees: its GPUs, and the Vulkan and OpenGL devices.
gpu:
	@$(SSH) 'lspci -nnk | grep -A2 -iE "vga|3d|display"; \
		echo; ls -l /dev/dri; \
		echo; vulkaninfo --summary 2>&1 | grep -E "deviceName|driverName|ERROR" || true; \
		echo; eglinfo -B -p surfaceless 2>/dev/null | grep -E "renderer" || true'

# Builds llama-bench in the guest, runs it, and copies the results back to results/.
bench: sync
	@$(SSH) 'LABEL=$(LABEL) LLAMA_REF=$(LLAMA_REF) RESULTS=/workspace/results /workspace/gpu-bench.sh'; \
	rc=$$?; mkdir -p results; \
	rsync -a -e "ssh $(SSH_OPTS)" ubuntu@127.0.0.1:/workspace/results/ results/; \
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
	@if [ "$$(cat $(MODE) 2>/dev/null)" = passthrough ]; then $(MAKE) --no-print-directory vfio-unbind; fi

reload:
	@$(MAKE) --no-print-directory halt
	@$(MAKE) --no-print-directory up

# Stops QEMU and deletes .vm/, keeping the downloaded image. A GVT-g vGPU stays until
# `make vgpu-remove` or a reboot.
destroy:
	@if $(RUNNING); then \
		pid=$$(cat $(PID)); kill $$pid; \
		for i in $$(seq 1 50); do kill -0 $$pid 2>/dev/null || break; sleep 0.1; done; \
	fi
	@if [ "$$(cat $(MODE) 2>/dev/null)" = passthrough ]; then $(MAKE) --no-print-directory vfio-unbind; fi
	rm -rf $(VM_DIR)

purge:
	rm -f $(IMAGE)

# Moves each PCI function to the vfio-pci driver, so QEMU can take it.
vfio-bind:
	@sudo modprobe vfio-pci
	@for a in $(SYSFS_PCI); do \
		d=/sys/bus/pci/devices/$$a; \
		[ "$$(basename $$(readlink -f $$d/driver 2>/dev/null))" = vfio-pci ] && continue; \
		echo "$$a: $$(basename $$(readlink -f $$d/driver 2>/dev/null) 2>/dev/null || echo none) -> vfio-pci"; \
		echo vfio-pci | sudo tee $$d/driver_override >/dev/null; \
		if [ -e $$d/driver ]; then echo $$a | sudo tee $$d/driver/unbind >/dev/null; fi; \
		echo $$a | sudo tee /sys/bus/pci/drivers_probe >/dev/null; \
	done

# Gives each PCI function back to its host driver.
vfio-unbind:
	@for a in $(SYSFS_PCI); do \
		d=/sys/bus/pci/devices/$$a; \
		[ "$$(basename $$(readlink -f $$d/driver 2>/dev/null))" = vfio-pci ] || continue; \
		echo "$$a: vfio-pci -> host driver"; \
		echo | sudo tee $$d/driver_override >/dev/null; \
		echo $$a | sudo tee $$d/driver/unbind >/dev/null; \
		echo $$a | sudo tee /sys/bus/pci/drivers_probe >/dev/null; \
	done

# Creates the GVT-g vGPU, once per boot.
vgpu:
	@test -e /sys/bus/mdev/devices/$(GVT_UUID) || { \
		echo "Creating vGPU $(GVT_UUID) ($(GVT_TYPE)) on $(GVT_PCI)"; \
		echo $(GVT_UUID) | sudo tee /sys/bus/pci/devices/$(GVT_PCI)/mdev_supported_types/$(GVT_TYPE)/create >/dev/null; }

vgpu-remove:
	@if [ -e /sys/bus/mdev/devices/$(GVT_UUID) ]; then echo 1 | sudo tee /sys/bus/mdev/devices/$(GVT_UUID)/remove >/dev/null; fi

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' \
		| sed 's| \*.*|  $@|' | sha256sum -c

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
	cp $(OVMF_VARS) $@

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C qemu-gpu -f $@

# A FAT image labelled CIDATA works as a cloud-init seed, and mtools builds
# one without root.
$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed -e "s|@SSH_KEY@|$$(cat $(KEY).pub)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	rm -f $@
	mformat -i $@ -C -f 1440 -v CIDATA ::
	mcopy -i $@ $(VM_DIR)/seed/user-data $(VM_DIR)/seed/meta-data ::
