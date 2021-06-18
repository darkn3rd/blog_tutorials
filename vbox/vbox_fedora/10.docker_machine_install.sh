#!/usr/bin/env bash

VER=v0.14.0
BASE=https://github.com/docker/machine/releases/download/${VER}

# Download Artifact
curl -L ${BASE}/docker-machine-$(uname -s)-$(uname -m) \
  > /tmp/docker-machine

sudo install /tmp/docker-machine /usr/local/bin/docker-machine
