#!/usr/bin/env bash
# Runs last during `packer build`: removes caches and per-machine state, then frees
# unused disk blocks so the exported box only contains real data.
set -euo pipefail

apt-get -y autoremove --purge
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
journalctl --rotate && journalctl --vacuum-time=1s
find /var/log -type f -name '*.log' -exec truncate -s 0 {} +

# Regenerated on first boot (ssh-hostkeys.service for SSH, systemd for the machine id)
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id

# Discard free blocks (needs hard_drive_discard), then zero what's left for compression
fstrim -av || true
dd if=/dev/zero of=/EMPTY bs=1M status=none || true
rm -f /EMPTY
sync
