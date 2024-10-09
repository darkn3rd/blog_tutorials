#!/usr/bin/env bash

PROJ_HOME=~/vagrant-puppetserver

# craete directory structure
mkdir -p \
  $PROJ_HOME/site/{data,manifests,modules/hello_web/{files,manifests}}

cd $PROJ_HOME

# create files
touch \
 Vagrantfile \
 bootstrap.sh \
 site/manifests/site.pp \
 site/modules/hello_web/{manifests/init.pp,files/index.html,metadata.json}