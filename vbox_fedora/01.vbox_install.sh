#!/usr/bin/env bash

# Install Repository Entry
sudo cat <<-'VBOXREPOENTRY' > /etc/yum/repos.d/virtualbox.repo
[virtualbox]
name=Fedora $releasever - $basearch - VirtualBox
baseurl=http://download.virtualbox.org/virtualbox/rpm/fedora/$releasever/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.virtualbox.org/download/oracle_vbox.asc
VBOXREPOENTRY

# Upgrade Packages
sudo dnf -y update

# Test if reboot is needed
NEW_VER=$(rpm -qa kernel | sort -V | tail -n 1 | cut -d- -f2)
CUR_VER=$(uname -r | cut -d- -f1)
[[ ${NEW_VER//.} > ${OLD_VER//.} ]] \
  && echo "Kernel Updated from '${OLD}' to '${NEW}', please reboot"
