#!/usr/bin/env bash

# Install Common Tools
sudo apt install \
 apt-transport-https \
 ca-certificates \
 curl \
 gnupg \
 jq \
 software-properties-common \
 unzip

# Install Tools from Private Repos
sudo apt install terraform
sudo apt install vault
sudo apt install kubectl
sudo apt install helm
sudo apt install java-17-amazon-corretto-jdk
