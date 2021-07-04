#!/usr/bin/env bash

VER=$(
 curl -s https://releases.hashicorp.com/vagrant/ | \
 grep -oP '(\d\.){2}\d' | \
 head -1
)
PKG="vagrant_${VER}_$(uname -p).rpm"

curl -oL https://releases.hashicorp.com/vagrant/${VER}/${PKG}
sudo rpm -Uvh ${PKG}
