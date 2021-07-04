#!/usr/bin/env bash

# variables for readibility
PREFIX=https://raw.githubusercontent.com
PATH=Homebrew/install/master/install
URL=${PREFIX}/${PATH}

# install homebrew w/ ruby install script
/usr/bin/ruby -e "$(curl -fsSL ${URL})"
