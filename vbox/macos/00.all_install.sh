#!/usr/bin/env bash

# variables for readibility
PREFIX=https://raw.githubusercontent.com
PATH=Homebrew/install/master/install
URL=${PREFIX}/${PATH}

# install homebrew w/ ruby install script
/usr/bin/ruby -e "$(curl -fsSL ${URL})"

# Install All Packages at Once
cat <<-'BREWFILE_EOF' > Brewfile
cask 'virtualbox'
cask 'virtualbox-extension-pack'
cask 'vagrant'
tap 'chef/chef'
cask 'chefdk'
cask 'docker-toolbox'
cask 'minikube'
brew 'kubectl'
BREWFILE_EOF
brew bundle --verbose
