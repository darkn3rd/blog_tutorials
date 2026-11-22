WORKSPACE := /workspace
PROVISION ?= false
PROVISION_FLAG := $(if $(filter true,$(PROVISION)),--provision,--no-provision)
BOX_VOLUME := hako-VAGRANTSLASH-ubuntu-26.04_vagrant_box_image
VIRSH := virsh --connect qemu:///system

.PHONY: up provision playbook verify ssh status halt reload destroy purge

up:
	vagrant up --provider=libvirt $(PROVISION_FLAG)

provision:
	vagrant provision

playbook:
	vagrant ssh-config > .vagrant/ssh.config
	ansible-playbook playbook.yaml

verify:
	curl --include --fail http://localhost:8080

ssh:
	vagrant ssh -- -t 'cd $(WORKSPACE) && exec bash -l'

status:
	vagrant status

halt:
	vagrant halt

reload:
	vagrant reload $(PROVISION_FLAG)

destroy:
	vagrant destroy --force

# vagrant-libvirt also copies the box image into libvirt's default storage pool,
# and `vagrant box remove` leaves that copy behind, so delete it too. Check
# access to libvirt first, so purge never stops halfway.
purge:
	@$(VIRSH) uri >/dev/null 2>&1 || { \
		echo "Can't connect to libvirt at qemu:///system." >&2; \
		echo "Is your login session in the libvirt group? Check with: id -nG" >&2; \
		echo "If not, log out and back in, or run: newgrp libvirt" >&2; \
		exit 1; }
	@if [ -e .vagrant/machines/dev/libvirt/id ]; then \
		echo "The dev VM still uses the box; run make destroy first." >&2; exit 1; \
	fi
	@if vagrant box list | grep -q '^hako/ubuntu-26.04 *(libvirt'; then \
		vagrant box remove hako/ubuntu-26.04 --provider libvirt --all --force; \
	else \
		echo "No cached box to remove."; \
	fi
	@vols=$$($(VIRSH) vol-list default | awk '/$(BOX_VOLUME)/ { print $$1 }'); \
	if [ -n "$$vols" ]; then \
		echo "Deleting the box image from libvirt's default storage pool..."; \
		for vol in $$vols; do $(VIRSH) vol-delete --pool default "$$vol"; done; \
	else \
		echo "No box image in libvirt's default storage pool."; \
	fi
