#!/usr/bin/env bash
WORKAREA=${HOME}/vbox_tutorial

mkdir -p ${WORKAREA}/mygentoo && cd ${WORKAREA}/mygentoo
vagrant init generic/gentoo && vagrant up

# install & run neofetch
vagrant ssh --command 'sudo emerge -a app-misc/neofetch'
vagrant ssh --command 'neofetch'
