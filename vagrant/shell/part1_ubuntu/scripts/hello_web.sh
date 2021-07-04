#!/usr/bin/env bash

#### Set variables with intelligent defaults
APACHE_PACKAGE=${1:-'apache2'}
APACHE_SERVICE=${2:-'apache2'}
APACHE_DOCROOT=${3:-'/var/www/html'}

#### Download and Install Package
apt-get update
apt-get install -y ${APACHE_PACKAGE}

#### Start, Enable Service
systemctl start ${APACHE_SERVICE}.service
systemctl enable ${APACHE_SERVICE}.service

#### Create Content
cat <<-'HTML' > ${APACHE_DOCROOT}/index.html
<html>
 <body>
 <h1>Hello World!</h1>
 </body>
</html>
HTML
