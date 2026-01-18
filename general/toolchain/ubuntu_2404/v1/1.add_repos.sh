#!/usr/bin/env bash

main() {
  add_hashicorp_repo
  add_kubernetes_repo
  add_helm_repo
  add_corretto_repo

  sudo apt update=
}

add_hashicorp_repo() {
  KEY="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
  sudo rm -rf $KEY

  # Install HashiCorp's GPG key to package provided keyring area
  wget -O - https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor -o $KEY

  # Add the official HashiCorp repository to your system.
  ARCH=$(dpkg --print-architecture)
  CODE=$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release)
  OPTIONS="arch=$ARCH signed-by=$KEY"
  URI="https://apt.releases.hashicorp.com "
  echo "deb [$OPTIONS] $URI $CODE main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list
}

add_kubernetes_repo() {
  KEY="/usr/share/keyrings/kubernetes-apt-keyring.gpg"
  sudo rm -rf $KEY

  # Install Kubernetes's GPG key to package provided keyring area
  wget -O - https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
    | sudo gpg --dearmor -o $KEY
  
  # Add the official Kubernetes repository to your system.
  OPTIONS="signed-by=$KEY"
  URI="https://pkgs.k8s.io/core:/stable:/v1.35/deb/"
  echo "deb [$OPTIONS] $URI /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list
}

add_helm_repo() {
  KEY="/usr/share/keyrings/helm.gpg"
  sudo rm -rf $KEY

  # Install Helms's GPG key to package provided keyring area
  wget -O - https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
    | sudo gpg --dearmor -o $KEY
  
  # Add the official Helm repository to your system.
  OPTIONS="signed-by=$KEY"
  URI="https://packages.buildkite.com/helm-linux/helm-debian/any/"
  echo "deb [$OPTIONS] $URI any main" \
    | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
}

add_corretto_repo() {
  KEY=/usr/share/keyrings/corretto-keyring.gpg
  sudo rm -rf $KEY

  # Install Corretto's GPG key to package provided keyring area
  wget -O - https://apt.corretto.aws/corretto.key \
    | sudo gpg --dearmor -o $KEY

  # Add the official Corretto repository to your system.
  OPTIONS="signed-by=$KEY"
  URI="https://apt.corretto.aws"
  echo "deb [$OPTIONS] $URI stable main" \
    | sudo tee /etc/apt/sources.list.d/corretto.list
}

main
