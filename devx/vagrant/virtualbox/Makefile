WORKSPACE := /workspace
PROVISION ?= false
PROVISION_FLAG := $(if $(filter true,$(PROVISION)),--provision,--no-provision)

.PHONY: up provision playbook ssh status halt destroy

up:
	vagrant up --provider=virtualbox $(PROVISION_FLAG)

provision:
	vagrant provision

playbook:
	vagrant ssh-config > .vagrant/ssh.config
	ansible-playbook playbook.yaml

ssh:
	vagrant ssh -- -t 'cd $(WORKSPACE) && exec bash -l'

status:
	vagrant status

halt:
	vagrant halt

destroy:
	vagrant destroy --force
