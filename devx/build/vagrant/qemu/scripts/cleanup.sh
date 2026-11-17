#!/bin/sh
# Runs inside the build VM, as root, before `vagrant package` saves its disk.
# Leaves the disk ready to be copied: no state tied to this one VM.
set -eu

echo "Waiting for cloud-init to finish..."
cloud-init status --wait >/dev/null || true

# cloud-init wrote a netplan file that matches this VM's MAC address. A VM made
# from the box gets a different one, so match any ethernet NIC by name instead,
# and stop cloud-init from writing network config again.
rm -f /etc/netplan/50-cloud-init.yaml
cat > /etc/netplan/01-vagrant.yaml <<'EOF'
network:
  version: 2
  ethernets:
    ethernet:
      match:
        name: "en*"
      dhcp4: true
EOF
chmod 600 /etc/netplan/01-vagrant.yaml
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-vagrant-network.cfg

# Forget this boot, so cloud-init treats the next one as a first boot if it
# finds a seed, and each VM gets its own machine ID.
cloud-init clean --logs --seed --machine-id

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
rm -f /root/.bash_history /home/vagrant/.bash_history

# Tell the virtual disk which blocks are free, so the packaged box is smaller.
fstrim --all || true
sync
