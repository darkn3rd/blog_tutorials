#!/usr/bin/env bash
WORKAREA=${HOME}/vbox_tutorial

##############################################
# Prerequisites: Mac OS X image
#   See: https://github.com/boxcutter/macos
##############################################

mkdir -p ${WORKAREA}/mymacosx && cd ${WORKAREA}/mymacosx
vagrant init my/macos-1012 && vagrant up

URL=https://github.com/KittyKatt/screenFetch/archive/master.zip
vagrant ssh --command "curl -OL ${URL}"
vagrant ssh --command 'unzip master.zip'
vagrant ssh --command './screenFetch-master/screenfetch-dev'
