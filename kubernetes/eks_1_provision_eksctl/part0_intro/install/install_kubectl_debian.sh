#!/usr/bin/env bash

sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | sudo apt-key add -
cp kubernetes.list /etc/apt/sources.list.d/kubernetes.list
sudo apt-get updatesudo apt-get install -y kubectl
