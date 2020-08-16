#!/usr/bin/env bash

TARBALL_NAME="eksctl_$(uname -s)_amd64.tar.gz"
HTTP_PATH="weaveworks/eksctl/releases/download/latest_release"
LOCATION="https://github.com/$HTTP_PATH/$TARBALL_NAME"

curl --silent --location $LOCATION | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
