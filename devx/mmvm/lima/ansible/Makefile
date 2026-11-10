APP_VMS := web1 web2 web3
VMS := $(APP_VMS) lb
PROVISION ?= false
VM ?= lb

.PHONY: up provision verify ssh status halt destroy purge

# Creates each VM from its template the first time, and starts it after that.
up:
	@for vm in $(VMS); do \
		if limactl list -q | grep -qx $$vm; then \
			limactl start --tty=false $$vm; \
		elif [ $$vm = lb ]; then \
			limactl start --tty=false --name=$$vm lima/loadbalancer.yaml; \
		else \
			limactl start --tty=false --name=$$vm lima/appserver.yaml; \
		fi || exit 1; \
	done
	@if [ "$(PROVISION)" = true ]; then $(MAKE) --no-print-directory provision; fi

provision:
	ansible-playbook playbook.yaml

verify:
	@for i in 1 2 3 4 5 6; do \
		curl --silent --fail http://localhost:8080 | grep '<title>'; \
	done

ssh:
	limactl shell $(VM) || true

status:
	limactl list $(VMS)

halt:
	@for vm in $(VMS); do limactl stop $$vm; done

destroy:
	limactl delete --force $(VMS)

purge:
	limactl prune
