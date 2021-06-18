#!/usr/bin/env bash
#
# Purpose: Create structure from $HOME directory, or directory of choosing
#

WORKAREA=${WORKAREA:-"${HOME}/vagrant-shell"}

mkdir -p ${WORKAREA}/scripts
touch ${WORKAREA}/{Vagrantfile,scripts/hello_web.sh}
