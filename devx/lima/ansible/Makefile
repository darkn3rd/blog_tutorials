VM := dev
WORKSPACE := /workspace
MOUNTS := .mounts=[{"location":"$(CURDIR)","mountPoint":"$(WORKSPACE)","writable":true}]
PROVISION ?= false

.PHONY: up provision ssh status halt destroy

up:
	@if limactl list -q | grep -qx '$(VM)'; then \
		limactl start --tty=false $(VM); \
	else \
		limactl start --tty=false --name=$(VM) --set '$(MOUNTS)' lima.yaml; \
	fi
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

provision:
	ansible-playbook playbook.yml

ssh:
	limactl shell --workdir $(WORKSPACE) $(VM) || true

status:
	limactl list $(VM)

halt:
	limactl stop $(VM)

destroy:
	limactl delete --force $(VM)

test:
	curl --include --fail http://localhost:8080
