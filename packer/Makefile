# Build the Ubuntu Vagrant box for this host's architecture and publish it to GitHub Releases.
#
#   make release          # validate -> build -> smoke-test -> publish
#
# VirtualBox can't emulate another CPU, so run this on an Apple silicon Mac for arm64 and on
# an Intel/AMD machine for amd64; the catalog on GitHub accumulates both.
# `publish` needs the GitHub CLI logged in (gh auth login) with write access to REPO.

TEMPLATE       := ubuntu
# Single source of truth for the default release is the Packer variable
UBUNTU_VERSION ?= $(shell sed -n '/variable "ubuntu_version"/,/^}/s/.*default *= *"\(.*\)"/\1/p' $(TEMPLATE)/variables.pkr.hcl)
ARCH           ?= $(if $(filter arm64 aarch64,$(shell uname -m)),arm64,amd64)
# Build VM disk and the .box go here, e.g. BUILD_DIR=/Volumes/External/packer
BUILD_DIR      ?= .
REPO           ?= $(shell gh repo view --json nameWithOwner -q .nameWithOwner)
BOX_NAME       ?= $(firstword $(subst /, ,$(REPO)))/ubuntu

BOX := $(BUILD_DIR)/ubuntu-$(UBUNTU_VERSION)-virtualbox-$(ARCH).box
PACKER_VARS := -var arch=$(ARCH) -var ubuntu_version=$(UBUNTU_VERSION) -var build_dir=$(BUILD_DIR)

.PHONY: help release init validate build smoke-test publish clean

help:
	@echo "Ubuntu $(UBUNTU_VERSION) ($(ARCH)) -> $(BOX)"
	@echo "  make release     validate, build, smoke-test, publish"
	@echo "  make validate    packer fmt -check and validate"
	@echo "  make build       packer build"
	@echo "  make smoke-test  boot the built box with Vagrant"
	@echo "  make publish     upload the box and update the catalog on GitHub"
	@echo "  make clean       remove the box and the build VM"
	@echo "Override with ARCH=, UBUNTU_VERSION=, BUILD_DIR=, REPO=, BOX_NAME="

release: validate build smoke-test publish

init:
	packer init $(TEMPLATE)

validate: init
	packer fmt -check -diff $(TEMPLATE)
	packer validate $(PACKER_VARS) $(TEMPLATE)

build: init
	mkdir -p $(BUILD_DIR)
	packer build -force $(PACKER_VARS) $(TEMPLATE)

smoke-test:
	bin/smoke-test.sh $(BOX) $(ARCH)

publish:
	REPO=$(REPO) BOX_NAME=$(BOX_NAME) bin/publish.sh $(BOX) $(UBUNTU_VERSION) $(ARCH)

clean:
	rm -rf $(BOX) $(BUILD_DIR)/output-ubuntu-$(ARCH)
