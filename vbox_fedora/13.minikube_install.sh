#!/usr/bin/env bash

BASE=https://storage.googleapis.com/minikube/releases

# Download & Install Artifact
curl -Lo minikube ${BASE}/v0.28.1/minikube-linux-amd64 && \
 chmod +x minikube && \
 sudo mv minikube /usr/local/bin/
