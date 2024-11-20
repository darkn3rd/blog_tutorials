#!/usr/bin/env bash

# Globals
ADMIN_USER="admin"
ADMIN_FIRST_NAME="admin"
ADMIN_LAST_NAME="admin"
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="examplepass"
ADMIN_PEM="admin.pem"
ORG_NAME="exampleorg"
ORG_FULL_NAME="Example, Inc."
ORG_PEM="example-validator.pem"

CHEFSERVER_FQDN="chefserver01.local"
CHEFWORKSTATION_FQDN="chefworkstation01.local"
HOSTNAME_FQDN="$(hostname -f)"
HOSTS_ENTRIES="192.168.49.3 $CHEFSERVER_FQDN ${CHEFSERVER_FQDN%%.*}
192.168.49.4 $CHEFWORKSTATION_FQDN ${CHEFWORKSTATION_FQDN%%.*}
192.168.49.5 node01.local node01
192.168.49.6 node02.local node02"

#######
# main
#####################
main() {
  setup_hosts_file

  if [[ "$HOSTNAME_FQDN" == "$CHEFSERVER_FQDN" ]]; then
    if ! sudo cinc-server-ctl status > /dev/null; then
      install_cinc_server
      configure_cinc_server
    else 
      echo "CINC Server is already installed! skipping"
    fi
  elif [[ "$HOSTNAME_FQDN" == "$CHEFWORKSTATION_FQDN" ]]; then
    install_cinc_workstation
  fi
}

#######
# setup /etc/hosts file
#####################
setup_hosts_file() {
  while read -r ENTRY; do
    grep -q ${ENTRY##* } /etc/hosts || \
      sudo sh -c "echo '$ENTRY' >> /etc/hosts"
  done <<< "$HOSTS_ENTRIES"
}

#######
# install_cinc_server
#####################
install_cinc_server() {
  curl -L https://omnitruck.cinc.sh/install.sh \
}

#######
# configure_cinc_server
#####################
configure_cinc_server() {
  sudo cinc-server-ctl reconfigure
  sudo cinc-server-ctl user-create $ADMIN_USER $ADMIN_FIRST_NAME $ADMIN_LAST_NAME \
    $ADMIN_EMAIL $ADMIN_PASSWORD --filename $ADMIN_PEM
  sudo cinc-server-ctl org-create $ORG_NAME $ORG_FULL_NAME \
    --association_user $ADMIN_USER --filename $ORG_PEM
}

#######
# install_cinc_workstation
#####################
install_cinc_workstation() {
  curl -L https://omnitruck.cinc.sh/install.sh \
    | sudo bash -s -- -P cinc-workstation -v 24

  # configuration ~/.cinc-workstation
}

main