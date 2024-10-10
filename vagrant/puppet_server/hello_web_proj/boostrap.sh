#!/usr/bin/env bash

# global variables
PUPPET_FQDN="puppetserver01.local"
HOSTNAME_FQDN="$(hostname -f)"
HOSTS_ENTRIES="192.168.50.4 puppetserver01.local puppetserver01
192.168.50.5 node01.local node01
192.168.50.6 node02.local node02"

# main 
main() {
  if [[ "$HOSTNAME_FQDN" == "$PUPPET_FQDN" ]]; then
    setup_hosts_file
    if ! systemctl status puppetserver > /dev/null; then
      install_puppet_server
      configure_puppet_server "$PUPPET_FQDN"
      sudo systemctl start puppetserver
      systemctl status puppetserver && sudo systemctl enable puppetserver
    else 
      echo "Puppet Server is already installed! skipping"
    fi
  else
    setup_hosts_file
    if ! command -v puppet > /dev/null; then
      install_puppet_agent
      configure_puppet_agent "$PUPPET_FQDN" "$HOSTNAME_FQDN"
    else
      echo "The Puppet Agent is already installed! skipping"
    fi
  fi
}

# setup /etc/hosts file
setup_hosts_file() {
  if [[ "$HOSTNAME_FQDN" == "$PUPPET_FQDN" ]]; then
    grep -q 'puppet$' /etc/hosts \
      || sudo sed -i '/127\.0\.0\.1 localhost/s/$/ puppet/' /etc/hosts
  fi

  while read -r ENTRY; do
    grep -q ${ENTRY##* } /etc/hosts || \
      sudo sh -c "echo '$ENTRY' >> /etc/hosts"
  done <<< "$HOSTS_ENTRIES"
}

# add remote registry for puppet packages
add_puppet_registry() {
  wget https://apt.puppetlabs.com/puppet8-release-$(lsb_release -cs).deb
  sudo dpkg -i puppet8-release-$(lsb_release -cs).deb
}

# install puppet agent
install_puppet_agent() {
  add_puppet_registry
  sudo apt-get -qq update
  sudo apt-get install -y puppet-agent
}

# install puppet server
install_puppet_server() {
  add_puppet_registry
  sudo apt-get -qq update
  sudo apt-get install -y puppetserver
}

# configure puppet server
configure_puppet_server() {
  # add entries if they do not yet exist
  grep -q "dns_alt_names" /etc/puppetlabs/puppet/puppet.conf \
    || sudo sh -c \
    "echo 'dns_alt_names = $1,${1%%.*},puppet' >> /etc/puppetlabs/puppet/puppet.conf"
  grep -q "certname" /etc/puppetlabs/puppet/puppet.conf \
    || sudo sh -c "echo 'certname = $1' >> /etc/puppetlabs/puppet/puppet.conf"

  # set default memory for test vm guest
  sudo sed -i \
    's/JAVA_ARGS="-Xms2g -Xmx2g/JAVA_ARGS="-Xms512m -Xmx512m/' \
    /etc/default/puppetserver
}

# configure puppet agent
configure_puppet_agent() {
  sudo bash -c "cat << EOF > /etc/puppetlabs/puppet/puppet.conf
server = $1
certname = $2
EOF"
}

main
