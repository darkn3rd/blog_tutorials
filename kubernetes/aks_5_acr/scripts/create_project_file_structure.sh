#!/usr/bin/env bash
mkdir -p ~/azure_acr/examples/{dgraph} && cd ~/azure_acr
touch env.sh helmfile.yaml ./examples/{dgraph,hello}/helmfile.yaml
