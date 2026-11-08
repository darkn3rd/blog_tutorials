WORKSPACE := /workspace
PROVISION ?= false
PROVISION_FLAG := $(if $(filter true,$(PROVISION)),--provision,--no-provision)

.PHONY: up provision playbook verify ssh status halt destroy purge

up:
	vagrant up --provider=virtualbox $(PROVISION_FLAG)

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

destroy:
	vagrant destroy --force

purge:
	@if vagrant box list | grep -q '^bento/ubuntu-26.04 *(virtualbox'; then \
		vagrant box remove bento/ubuntu-26.04 --provider virtualbox --all --force; \
	else \
		echo "No cached box to remove."; \
	fi
