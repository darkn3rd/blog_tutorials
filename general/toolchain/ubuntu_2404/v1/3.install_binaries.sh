#!/usr/bin/env bash

main() {
  # install AWS CLI
  install_binary_aws_cli
  install_binary_okta_aws_cli

  # install other binaries
  install_binary_kustomize
  install_binary_helmfile
}

install_binary_kustomize() {
  URL_PATH="kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
  URL_SCRIPT="https://raw.githubusercontent.com/$URL_PATH"
  curl -s "$URL_SCRIPT" | bash
  sudo mv ~/kustomize /usr/local/bin
}

install_binary_helmfile() {
  ARCH="amd64"
  VER="1.2.3"
  PKG="helmfile_${VER}_linux_$ARCH.tar.gz"
  URL_PATH="helmfile/helmfile/releases/download/v$VER/$PKG"
  URL="https://github.com/$URL_PATH"
  TEMP_DIR=$(mktemp -d)
  wget -qO- "$URL" | tar -xz -C "$TEMP_DIR"
  sudo mv $TEMP_DIR/helmfile /usr/local/bin
  rm -rf "$TEMP_DIR"
}

install_binary_okta_aws_cli() {
  ARCH="amd64"
  VER="2.5.1"
  PKG="okta-aws-cli_${VER}_linux_$ARCH.tar.gz"
  URL_PATH="okta/okta-aws-cli/releases/download/v$VER/$PKG"
  URL="https://github.com/$URL_PATH"
  TEMP_DIR=$(mktemp -d)
  wget -qO- "$URL" | tar -xz -C "$TEMP_DIR"
  sudo mv $TEMP_DIR/okta-aws-cli /usr/local/bin
  rm -rf "$TEMP_DIR"
}

install_binary_aws_cli() {
  TEMP_DIR=$(mktemp -d)
  PKG="awscli-exe-linux-x86_64.zip"
  wget "https://awscli.amazonaws.com/$PKG" -P $TEMP_DIR
  unzip $TEMP_DIR/$PKG -d $TEMP_DIR
  sudo $TEMP_DIR/aws/install
  rm -rf TEMP_DIR
}

main

