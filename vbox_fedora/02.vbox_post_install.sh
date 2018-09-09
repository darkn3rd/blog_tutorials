#!/usr/bin/env bash

# Install kernel development packages
sudo dnf install -y \
 binutils \
 gcc \
 make \
 patch \
 libgomp \
 glibc-headers \
 glibc-devel \
 kernel-headers \
 kernel-devel \
 dkms

# Install/Setup VirtualBox 5.2.x
sudo dnf install -y VirtualBox-5.2
sudo /usr/lib/virtualbox/vboxdrv.sh setup

# Test Version
vboxmanage --version
5.2.16r123759

# Enable Current User
usermod -a -G vboxusers ${USER}
