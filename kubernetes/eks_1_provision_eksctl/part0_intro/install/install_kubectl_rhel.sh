#!/usr/bin/env bash

sudo cp kubernetes.repo /etc/yum.repos.d/kubernetes.repo
sudo yum install -y kubectl
