#!/usr/bin/env bash

#### Set variables with intelligent defaults
APACHE_PACKAGE=${1:-'apache2'}
APACHE_SERVICE=${2:-'apache2'}
APACHE_DOCROOT=${3:-'/var/www/html'}

#### Download and Install Package
DISTRO=$(
 awk -F= '/^ID=/{print tolower($2) }' /etc/os-release \
  | tr -d '"'
)
case "${DISTRO}" in
  centos|rhel)
    yum install -y ${APACHE_PACKAGE}
    ;;
  fedora)
    dnf install -y ${APACHE_PACKAGE}
    ;;
  debian|ubuntu)
    apt-get update
    apt-get install -y ${APACHE_PACKAGE}
    ;;
  gentoo)
    emerge ${APACHE_PACKAGE}
    ;;
  arch)
    pacman -Syu --noconfirm
    pacman -S --noconfirm ${APACHE_PACKAGE}
    ;;
  *)
    echo "Distro '${DISTRO}' not supported" 2>&1
    exit 1
    ;;
esac

#### Start, Enable Service
case "${DISTRO}" in
  centos|rhel|fedora|debian|ubuntu|arch)
    systemctl start ${APACHE_SERVICE}.service
    systemctl enable ${APACHE_SERVICE}.service
    ;;
  gentoo)
    rc-update add ${APACHE_SERVICE} default
    /etc/init.d/${APACHE_SERVICE} start
    ;;
  *)
    echo "Distro '${DISTRO}' not supported" 2>&1
    exit 1
    ;;
esac

#### Create Content
cat <<-'HTML' > ${APACHE_DOCROOT}/index.html
<html>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>
HTML
