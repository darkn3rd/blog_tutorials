#!/usr/bin/env bash
WORKAREA=${HOME}/vbox_tutorial

##############################################
# Prerequisites: Windows2016 Image
#   See: https://github.com/mwrock/packer-templates
##############################################

mkdir -p ${WORKAREA}/mywindows && cd ${WORKAREA}/mywindows
vagrant init my/win2016 && vagrant up

curl -LO https://dl.bitvise.com/BvSshServer-Inst.exe

##############################################
# Further Steps using RDP
#  1. Login Into Graphical Windows Session
#   vagrant rdp
#  2. Run This Command from Prompt
#   \\VBOXSVR\vagrant\BvSsServer-Inst.exe
#  3. Enable Service with services.msc
##############################################
