#!/usr/bin/env bash

BASE=https://storage.googleapis.com/kubernetes-release/release
VER=$(curl -s ${BASE}/stable.txt)

# Download Artiface and Install
curl -Lo kubectl ${BASE}/${VER}/bin/linux/amd64/kubectl && \
 chmod +x kubectl && \
 sudo mv kubectl /usr/local/bin/
