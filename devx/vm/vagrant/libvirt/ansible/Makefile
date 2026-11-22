WORKSPACE := /workspace
PROVISION ?= false
PROVISION_FLAG := $(if $(filter true,$(PROVISION)),--provision,--no-provision)
BOX_VOLUME := hako-VAGRANTSLASH-ubuntu-26.04_vagrant_box_image

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
# and `vagrant box remove` leaves that copy behind, so delete it too.
purge:
	@if vagrant box list | grep -q '^hako/ubuntu-26.04 *(libvirt'; then \
		vagrant box remove hako/ubuntu-26.04 --provider libvirt --all --force; \
	else \
		echo "No cached box to remove."; \
	fi
	@virsh --connect qemu:///system vol-list default 2>/dev/null \
		| awk '/$(BOX_VOLUME)/ { print $$1 }' \
		| xargs -r -n1 virsh --connect qemu:///system vol-delete --pool default
