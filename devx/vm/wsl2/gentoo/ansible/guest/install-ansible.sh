#!/bin/sh
# Run as root by `make provision` before the playbook. Like Vagrant's ansible_local
# provisioner, it installs Ansible in the guest, since Ansible doesn't run on Windows.
set -eu

if command -v ansible-playbook >/dev/null && command -v sudo >/dev/null; then
  exit 0
fi

# A stage3 ships without the Gentoo ebuild repository.
[ -d /var/db/repos/gentoo/profiles ] || emerge-webrsync --quiet

# --getbinpkg uses Gentoo's binary package host, which the stage3 already trusts,
# instead of compiling Ansible and its Python dependencies.
emerge --quiet --getbinpkg --noreplace app-admin/ansible app-admin/sudo
