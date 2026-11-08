VM := dev
SSH_PORT ?= 2222
HTTP_PORT ?= 8080
PROVISION ?= false
CPUS ?= 2
MEMORY_MB ?= 4096
DISK_SIZE_MB ?= 20480

IMAGE_BASE_URL ?= https://cloud-images.ubuntu.com/releases/26.04/release
IMAGE_NAME := ubuntu-26.04-server-cloudimg-arm64.img
IMAGE ?= images/$(IMAGE_NAME)

VM_DIR := .vm
DISK := $(VM_DIR)/disk.vdi
SEED := $(VM_DIR)/seed.iso
KEY := $(VM_DIR)/id_ed25519
CREATED := $(VM_DIR)/created

VBOX := VBoxManage -q
SSH := ssh -i $(KEY) -p $(SSH_PORT) -o BatchMode=yes -o ConnectTimeout=5 \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	ubuntu@127.0.0.1
VM_STATE := $(VBOX) showvminfo $(VM) --machinereadable 2>/dev/null | sed -n 's/^VMState="\(.*\)"$$/\1/p'

.DELETE_ON_ERROR:
.PHONY: up start provision verify ssh status halt destroy purge

up: start
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

start: $(CREATED)
	@if [ "$$($(VM_STATE))" = running ]; then \
		echo "VM is already running."; \
	else \
		$(VBOX) startvm $(VM) --type headless; \
	fi
	@echo "Waiting for SSH..."
	@for i in $$(seq 1 90); do \
		$(SSH) true 2>/dev/null && break; \
		if [ "$$i" = 90 ]; then echo "SSH did not come up; see $(VM_DIR)/console.log" >&2; exit 1; fi; \
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
	@state="$$($(VM_STATE))"; \
	if [ "$$state" = running ]; then \
		echo "running, ssh 127.0.0.1:$(SSH_PORT), http 127.0.0.1:$(HTTP_PORT)"; \
	else \
		echo "$${state:-not created}"; \
	fi

halt:
	@if [ "$$($(VM_STATE))" = running ]; then \
		$(VBOX) controlvm $(VM) acpipowerbutton; \
		for i in $$(seq 1 60); do [ "$$($(VM_STATE))" = running ] || exit 0; sleep 1; done; \
		echo "Guest did not shut down; powering off." >&2; \
		$(VBOX) controlvm $(VM) poweroff; \
	fi

destroy:
	@if [ "$$($(VM_STATE))" = running ]; then $(VBOX) controlvm $(VM) poweroff; sleep 2; fi
	@if [ -n "$$($(VM_STATE))" ]; then $(VBOX) unregistervm $(VM) --delete; fi
	rm -rf $(VM_DIR)

$(IMAGE):
	mkdir -p $(dir $@)
	curl -fL --progress-bar -o $@ $(IMAGE_BASE_URL)/$(IMAGE_NAME)
	curl -fsSL $(IMAGE_BASE_URL)/SHA256SUMS | grep ' \*$(IMAGE_NAME)$$' | sed 's| \*.*|  $@|' | shasum -a 256 -c

$(DISK): | $(IMAGE)
	mkdir -p $(VM_DIR)
	qemu-img convert -O vdi $(IMAGE) $@
	$(VBOX) modifymedium disk $(abspath $@) --resize $(DISK_SIZE_MB)

$(KEY):
	mkdir -p $(VM_DIR)
	ssh-keygen -q -t ed25519 -N '' -C virtualbox-example -f $@

$(SEED): cloud-init/user-data cloud-init/meta-data | $(KEY)
	mkdir -p $(VM_DIR)/seed
	sed "s|@SSH_KEY@|$$(cat $(KEY).pub)|" cloud-init/user-data > $(VM_DIR)/seed/user-data
	cp cloud-init/meta-data $(VM_DIR)/seed/meta-data
	hdiutil makehybrid -quiet -ov -iso -joliet -default-volume-name cidata -o $@ $(VM_DIR)/seed

$(CREATED): | $(DISK) $(SEED)
	$(VBOX) createvm --name=$(VM) --platform-architecture=arm --ostype=Ubuntu_arm64 --basefolder=$(abspath $(VM_DIR)) --register
	$(VBOX) modifyvm $(VM) --cpus=$(CPUS) --memory=$(MEMORY_MB) --chipset=armv8virtual --firmware=efi \
		--graphicscontroller=qemuramfb --audio-enabled=off --usb-xhci=on \
		--nic1=nat --nic-type1=virtio --cable-connected1=on \
		--nat-pf1=ssh,tcp,127.0.0.1,$(SSH_PORT),,22 --nat-pf1=http,tcp,127.0.0.1,$(HTTP_PORT),,80 \
		--uart1=0x3F8 4 --uart-mode1=file $(abspath $(VM_DIR))/console.log
	$(VBOX) storagectl $(VM) --name=SATA --add=sata --controller=IntelAhci --portcount=2
	$(VBOX) storageattach $(VM) --storagectl=SATA --port=0 --type=hdd --medium=$(abspath $(DISK))
	$(VBOX) storageattach $(VM) --storagectl=SATA --port=1 --type=dvddrive --medium=$(abspath $(SEED))
	$(VBOX) sharedfolder add $(VM) --name=workspace --hostpath=$(CURDIR)
	touch $@

purge:
	rm -f $(IMAGE)
