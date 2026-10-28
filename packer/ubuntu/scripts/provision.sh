#!/usr/bin/env bash
# Runs inside the box during `packer build`: brings packages up to date and
# adjusts the image for use as a Vagrant box.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y dist-upgrade

# Vagrant configures the hostname and network itself; cloud-init would only slow down first boot
touch /etc/cloud/cloud-init.disabled

# cleanup.sh removes the SSH host keys so every VM gets its own; regenerate them before sshd starts
cat > /etc/systemd/system/ssh-hostkeys.service <<'UNIT'
[Unit]
Description=Generate missing SSH host keys
ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key
Before=ssh.service ssh.socket

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable ssh-hostkeys.service
