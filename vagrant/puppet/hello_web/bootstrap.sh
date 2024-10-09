#!/bin/sh
command -v puppet > /dev/null && { echo "Puppet is installed! skipping" ; exit 0; }

ID=$(grep -oP '(?<=^ID=).*' /etc/os-release | tr -d '"')

case "${ID}" in
  rocky)
    VERS=$(grep -oP '(?<=PLATFORM_ID="platform:el).*[0-9]' /etc/os-release)
    sudo rpm -Uvh https://yum.puppet.com/puppet8-release-el-${VERS}.noarch.rpm
    sudo yum install -y puppet-agent
    ;;
  debian|ubuntu)
    wget https://apt.puppetlabs.com/puppet8-release-$(lsb_release -cs).deb
    sudo dpkg -i puppet8-release-$(lsb_release -cs).deb
    sudo apt-get -qq update
    sudo apt-get install -y puppet-agent
    ;;
  *)
    echo "ERROR: Distro '${ID}' not supported" 2>&1
    exit 1
    ;;
esac
