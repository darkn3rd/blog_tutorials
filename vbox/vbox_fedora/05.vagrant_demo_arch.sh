#!/usr/bin/env bash
WORKAREA=${HOME}/vbox_tutorial

mkdir ${WORKAREA}/myarch && cd ${WORKAREA}/myarch
vagrant init archlinux/archlinux && vagrant up

# install and run neofetch
vagrant ssh --command 'sudo pacman -S neofetch'
vagrant ssh --command 'neofetch'
