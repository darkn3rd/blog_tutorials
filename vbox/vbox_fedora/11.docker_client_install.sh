#!/usr/bin/env bash

REPOURL=https://download.docker.com/linux/fedora/docker-ce.repo

sudo dnf config-manager --add-repo ${REPO_URL}
sudo dnf install -y docker-ce
