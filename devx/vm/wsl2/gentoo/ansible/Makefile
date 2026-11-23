# Chocolatey's GNU make runs recipes with cmd.exe and ignores SHELL unless it's a POSIX
# sh, so every recipe is one command and the steps that need logic live in wsl.ps1.
# Make still decides what to build: the download, the image and the machine are files.

NAME ?= gentoo-dev
PROVISION ?= false
# DRY_RUN=true passes -WhatIf, so each step prints its commands instead of running them.
DRY_RUN ?= false
PWSH ?= pwsh

MIRROR ?= https://distfiles.gentoo.org/releases/amd64/autobuilds
FLAVOR ?= stage3-amd64-systemd
DOWNLOAD := images/$(FLAVOR).tar.xz
IMAGE := images/gentoo-wsl.tar
VM_DIR := .vm
VHD := $(VM_DIR)/ext4.vhdx

# nginx listens on this port in the guest, and WSL forwards it to the same port on
# localhost in Windows. Changing it takes effect at the next `make provision`.
HTTP_PORT ?= 8080
CHECK_CONFIG_URL ?= https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh

step = $(PWSH) -NoProfile -NonInteractive -ExecutionPolicy Bypass -File wsl.ps1 $(1) \
	-Name $(NAME) -Mirror $(MIRROR) -Flavor $(FLAVOR) -Download $(DOWNLOAD) \
	-Image $(IMAGE) -VmDir $(VM_DIR) -HttpPort $(HTTP_PORT) $(if $(filter true,$(DRY_RUN)),-WhatIf)

.DELETE_ON_ERROR:
.PHONY: download image machine up start provision verify check-config ssh status \
	versions halt reload destroy purge

up: start $(if $(filter true,$(PROVISION)),provision)

download: $(DOWNLOAD)

image: $(IMAGE)

machine: $(VHD)

$(DOWNLOAD):
	$(call step,download)

$(IMAGE): $(DOWNLOAD) image.mtree image/etc/wsl.conf
	$(call step,image)

# The machine is a copy of the image, so rebuilding the image doesn't recreate it.
$(VHD): | $(IMAGE)
	$(call step,create)

start: $(VHD)
	$(call step,start)

provision: start
	$(call step,provision)

verify:
	curl --include --fail http://localhost:$(HTTP_PORT)

check-config: start
	$(call step,check-config) -CheckConfigUrl $(CHECK_CONFIG_URL)

ssh:
	$(call step,ssh)

status:
	@$(call step,status)

versions:
	@$(call step,versions)

halt:
	$(call step,halt)

reload:
	$(MAKE) halt
	$(MAKE) up

destroy:
	$(call step,destroy)

purge:
	$(call step,purge)
