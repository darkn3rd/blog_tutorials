#!/usr/bin/env bash

VER=3.2.30
PKG=chefdk-${VER}-1.el7.x86_64.rpm

URL=https://packages.chef.io/files/stable/chefdk/${VER}/el/7/${PKG}

curl -O ${URL}
sudo rpm -Uvh ${PKG}
