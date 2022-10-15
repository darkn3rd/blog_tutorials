#!/usr/bin/env bash

# https://www.consul.io/docs/k8s/installation/install-cli
if [[ "$(uname -s)" == "Linux" ]]; then
  if cat /etc/os-release | grep -qE 'ubuntu|debian'; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install consul-k8s
  elif cat /etc/os-release | grep -qE 'fedora|Red Hat'; then
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    sudo yum -y install consul-k8s
  fi
elif  [[ "$(uname -s)" == "Darwin" ]]; then
  brew tap hashicorp/tap
  brew install hashicorp/tap/consul-k8s
fi
