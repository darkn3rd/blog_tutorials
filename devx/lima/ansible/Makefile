VM := dev
WORKSPACE := /workspace
MOUNTS := .mounts=[{"location":"$(CURDIR)","mountPoint":"$(WORKSPACE)","writable":true}]
PROVISION ?= false

.PHONY: deps versions up provision verify ssh status halt destroy

deps:
	@for pair in limactl:lima ansible-playbook:ansible; do \
		command -v "$${pair%%:*}" >/dev/null && continue; \
		command -v brew >/dev/null || { echo "$${pair##*:} is missing and Homebrew isn't installed. See the README for other ways to install it." >&2; exit 1; }; \
		brew install "$${pair##*:}" || exit 1; \
	done
	@echo "Lima and Ansible are installed."

versions:
	@printf "%-14s%s\n" \
		macOS: $$(sw_vers --productVersion) \
		Lima: $$(limactl --version | cut -d' ' -f3) \
		ansible-core: $$(ansible --version | sed -n '1s/.* //; 1s/]//p')

up:
	@if limactl list -q | grep -qx '$(VM)'; then \
		limactl start --tty=false $(VM); \
	else \
		limactl start --tty=false --name=$(VM) --set '$(MOUNTS)' lima.yaml; \
	fi
	@if [ "$(PROVISION)" = true ]; then $(MAKE) provision; fi

provision:
	ansible-playbook playbook.yaml

ssh:
	limactl shell --workdir $(WORKSPACE) $(VM) || true

status:
	limactl list $(VM)

halt:
	limactl stop $(VM)

destroy:
	limactl delete --force $(VM)

verify:
	curl --include --fail http://localhost:8080
